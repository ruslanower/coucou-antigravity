import Foundation
import AppKit

final class SocketServer {
    static let shared = SocketServer()

    private var listenFd: Int32 = -1
    private var isRunning = false
    private let socketPath: String
    private let tmpSocketPaths = ["/tmp/rango.sock", "/tmp/tuktuk.sock", "/tmp/notchbuddy.sock"]

    private init() {
        let appSupport = NSString("~/Library/Application Support/NotchBuddy").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
        self.socketPath = (appSupport as NSString).appendingPathComponent("nb.sock")
    }

    func start() {
        guard !isRunning else { return }
        signal(SIGPIPE, SIG_IGN)
        unlink(socketPath)
        for p in tmpSocketPaths { unlink(p) }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("[Rango] Failed to create socket: %d", errno)
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
            NSLog("[Rango] Failed to bind socket: %d", errno)
            close(fd)
            return
        }

        guard listen(fd, 20) == 0 else {
            NSLog("[Rango] Failed to listen on socket: %d", errno)
            close(fd)
            return
        }

        // Create symlinks in /tmp for universal discovery
        for p in tmpSocketPaths {
            _ = symlink(socketPath, p)
        }

        self.isRunning = true
        NSLog("[Rango] Socket server listening at: %@", socketPath)

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
        NSLog("[Rango] Processing message: type=%@ tool=%@", type, toolName)

        // 1. Close / Dismiss / Question completion / Stop
        if type == "close" || type == "dismiss" || type == "Stop" || (type == "PostToolUse" && toolName == "ask_question") {
            Task { @MainActor in
                AppState.shared.close()
            }
            return
        }

        // 2. Interactive Questions (AskUserQuestion / ask_question)
        if (type == "ask_question" || toolName == "ask_question" || toolName == "AskUserQuestion" || type == "ask_user_question") && type != "PostToolUse" {
            let (questionText, options) = parseQuestionPayload(obj)
            if !questionText.isEmpty && !options.isEmpty {
                Task { @MainActor in
                    AppState.shared.showQuestion(question: questionText, options: options)
                }
                return
            }
        }

        // 3. Manual status notifications
        if type == "status" {
            let text = obj["text"] as? String ?? "Обробка..."
            Task { @MainActor in
                AppState.shared.showStatus(text)
            }
            return
        }

        // 4. PreToolUse - Live telemetry of active Antigravity tools
        if type == "PreToolUse" {
            let toolInput = obj["tool_input"] as? [String: Any]
            let action = (toolInput?["toolAction"] as? String) ?? (toolInput?["toolSummary"] as? String)

            let statusText: String
            switch toolName {
            case "run_command":
                if let cmd = toolInput?["CommandLine"] as? String, !cmd.isEmpty {
                    let firstWord = cmd.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first ?? ""
                    if !firstWord.isEmpty && firstWord.count <= 15 {
                        statusText = "⚡️ Виконую: \(firstWord)..."
                    } else if let action = action, !action.isEmpty {
                        statusText = "⚡️ \(action)"
                    } else {
                        statusText = "⚡️ Виконую команду..."
                    }
                } else if let action = action, !action.isEmpty {
                    statusText = "⚡️ \(action)"
                } else {
                    statusText = "⚡️ Виконую команду..."
                }

            case "write_to_file", "replace_file_content":
                if let target = (toolInput?["TargetFile"] as? String)?.components(separatedBy: "/").last, !target.isEmpty {
                    statusText = "📝 Змінюю \(target)"
                } else if let action = action, !action.isEmpty {
                    statusText = "📝 \(action)"
                } else {
                    statusText = "📝 Змінюю файл..."
                }

            case "view_file":
                if let path = (toolInput?["AbsolutePath"] as? String)?.components(separatedBy: "/").last, !path.isEmpty {
                    statusText = "📄 Читаю \(path)"
                } else if let action = action, !action.isEmpty {
                    statusText = "📄 \(action)"
                } else {
                    statusText = "📄 Читаю файл..."
                }

            case "search_web":
                if let q = toolInput?["query"] as? String, !q.isEmpty {
                    let shortQ = q.count > 20 ? String(q.prefix(18)) + "..." : q
                    statusText = "🌐 Пошук: \(shortQ)"
                } else {
                    statusText = "🌐 Шукаю в інтернеті..."
                }

            case "read_url_content":
                statusText = "🌐 Читаю сторінку..."

            case "invoke_subagent":
                statusText = "🤖 Запускаю ШІ-агента..."

            default:
                if let action = action, !action.isEmpty {
                    statusText = "🔧 \(action)"
                } else if !toolName.isEmpty {
                    statusText = "🔧 Виконую: \(toolName)"
                } else {
                    statusText = "⚡️ Antigravity працює..."
                }
            }

            Task { @MainActor in
                AppState.shared.showStatus(statusText, autoDismissAfter: 12.0)
            }
            return
        }

        // 5. PostToolUse - Tool completion feedback
        if type == "PostToolUse" {
            Task { @MainActor in
                if case .status = AppState.shared.state {
                    AppState.shared.showStatus("✅ Готово", autoDismissAfter: 1.2)
                }
            }
            return
        }

        // 6. PreInvocation - Agent thinking / preparing
        if type == "PreInvocation" {
            Task { @MainActor in
                if case .question = AppState.shared.state { return }
                AppState.shared.showStatus("💭 Думаю...", autoDismissAfter: 6.0)
            }
            return
        }

        // 7. PostInvocation - Agent finished turn
        if type == "PostInvocation" {
            Task { @MainActor in
                if case .status = AppState.shared.state {
                    AppState.shared.scheduleCloseStatus(delay: 1.2)
                }
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
