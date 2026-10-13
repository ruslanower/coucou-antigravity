import Foundation
import AppKit

final class SocketServer {
    static let shared = SocketServer()

    private var listenFd: Int32 = -1
    private var isRunning = false
    private let socketPath: String

    private init() {
        let appSupport = NSString("~/Library/Application Support/NotchBuddy").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
        self.socketPath = (appSupport as NSString).appendingPathComponent("nb.sock")
    }

    func start() {
        guard !isRunning else { return }
        signal(SIGPIPE, SIG_IGN)
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("[CoucouAntigravity] Failed to create socket: %d", errno)
            return
        }
        self.listenFd = fd

        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        socketPath.withCString {
            _ = strncpy(&addr.sun_path.0, $0, 100)
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, addrLen)
            }
        }

        guard bindRes == 0 else {
            NSLog("[CoucouAntigravity] Failed to bind socket: %d", errno)
            close(fd)
            return
        }

        guard listen(fd, 20) == 0 else {
            NSLog("[CoucouAntigravity] Failed to listen on socket: %d", errno)
            close(fd)
            return
        }

        self.isRunning = true
        NSLog("[CoucouAntigravity] Socket server listening at: %@", socketPath)

        // Run accept loop on background thread
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.acceptLoop()
        }
    }

    private func acceptLoop() {
        while isRunning && listenFd >= 0 {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFd = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(listenFd, $0, &clientLen)
                }
            }

            guard clientFd >= 0 else {
                if !isRunning { break }
                usleep(10000)
                continue
            }

            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.handleClient(fd: clientFd)
            }
        }
    }

    private func handleClient(fd: Int32) {
        defer { close(fd) }

        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))

        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let data = Data(buffer[0..<bytesRead])
        guard let jsonString = String(data: data, encoding: .utf8) else { return }

        for line in jsonString.components(separatedBy: .newlines) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any] else {
                continue
            }
            processMessage(obj)
        }

        let ack = "{\"status\":\"ok\"}\n"
        if let ackData = ack.data(using: .utf8) {
            _ = ackData.withUnsafeBytes { ptr in
                write(fd, ptr.baseAddress, ackData.count)
            }
        }
    }

    private func processMessage(_ obj: [String: Any]) {
        let type = (obj["type"] as? String) ?? (obj["event"] as? String) ?? (obj["coucou_kind"] as? String) ?? (obj["hook_event_name"] as? String) ?? ""
        let toolName = (obj["tool_name"] as? String) ?? (obj["tool"] as? String) ?? ""
        NSLog("[CoucouAntigravity] Processing message: type=%@ tool=%@", type, toolName)

        // 1. Direct or Legacy Question
        if type == "ask_question" || toolName == "ask_question" || toolName == "AskUserQuestion" || type == "ask_user_question" {
            let (questionText, options) = parseQuestionPayload(obj)
            if !questionText.isEmpty && !options.isEmpty {
                Task { @MainActor in
                    AppState.shared.showQuestion(question: questionText, options: options)
                }
                return
            }
        }

        // 2. Close / Dismiss
        if type == "close" || type == "dismiss" || type == "Stop" || (type == "PostToolUse" && toolName == "ask_question") {
            Task { @MainActor in
                AppState.shared.close()
            }
            return
        }

        // 3. Status notification
        if type == "status" {
            let text = obj["text"] as? String ?? "Обробка..."
            Task { @MainActor in
                AppState.shared.showStatus(text)
            }
            return
        }

        if type == "PreInvocation" {
            Task { @MainActor in
                AppState.shared.showStatus("Antigravity працює...")
            }
            return
        }
    }

    private func parseQuestionPayload(_ obj: [String: Any]) -> (String, [String]) {
        // Direct format
        if let q = obj["question"] as? String, let opts = obj["options"] as? [String] {
            return (q, opts)
        }

        // tool_input format
        if let toolInput = obj["tool_input"] as? [String: Any] {
            var rawQuestions: [[String: Any]] = []
            if let list = toolInput["questions"] as? [[String: Any]] {
                rawQuestions = list
            } else if let jsonStr = toolInput["questions"] as? String,
                      let strData = jsonStr.data(using: .utf8),
                      let parsed = (try? JSONSerialization.jsonObject(with: strData)) as? [[String: Any]] {
                rawQuestions = parsed
            }

            if let firstQ = rawQuestions.first {
                let qText = firstQ["question"] as? String ?? ""
                var options: [String] = []
                if let rawOpts = firstQ["options"] as? [Any] {
                    for item in rawOpts {
                        if let s = item as? String {
                            options.append(s)
                        } else if let d = item as? [String: Any], let label = d["label"] as? String {
                            options.append(label)
                        }
                    }
                }
                return (qText, options)
            }
        }

        return ("", [])
    }
}
