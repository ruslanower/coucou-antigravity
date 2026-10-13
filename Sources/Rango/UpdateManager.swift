import Foundation
import AppKit
import Combine

public struct AppVersionInfo: Codable, Equatable {
    public let version: String
    public let build: Int
    public let commit: String?
    public let releaseNotes: String?
    public let downloadUrl: String?

    public init(version: String, build: Int, commit: String? = nil, releaseNotes: String? = nil, downloadUrl: String? = nil) {
        self.version = version
        self.build = build
        self.commit = commit
        self.releaseNotes = releaseNotes
        self.downloadUrl = downloadUrl
    }
}

@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()

    @Published public var isChecking: Bool = false
    @Published public var isUpdating: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var remoteVersion: AppVersionInfo?
    @Published public var lastCheckTime: Date?
    @Published public var statusMessage: String = ""

    private let remoteVersionURL = URL(string: "https://raw.githubusercontent.com/ruslanower/rango/main/version.json")!
    private var checkTimer: AnyCancellable?

    public var currentVersion: AppVersionInfo {
        if let url = Bundle.main.url(forResource: "version", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let info = try? JSONDecoder().decode(AppVersionInfo.self, from: data) {
            return info
        }
        let versionStr = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1"
        return AppVersionInfo(
            version: versionStr,
            build: 2,
            commit: "5850c2a",
            releaseNotes: "Автоматичне оновлення, новий преміальний 3D-аватар хамелеона",
            downloadUrl: nil
        )
    }

    private init() {
        if let savedDate = UserDefaults.standard.object(forKey: "rango_last_update_check") as? Date {
            self.lastCheckTime = savedDate
        }
    }

    public func startPeriodicCheck() {
        // Initial check after 4 seconds delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            Task { @MainActor in
                await self?.checkForUpdates(silent: true)
            }
        }

        // Periodic check every 4 hours
        checkTimer = Timer.publish(every: 4 * 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkForUpdates(silent: true)
                }
            }
    }

    public func checkForUpdates(silent: Bool = false) async {
        guard !isChecking && !isUpdating else { return }
        isChecking = true
        statusMessage = "Перевірка оновлень..."

        do {
            var request = URLRequest(url: remoteVersionURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 10.0

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let remote = try JSONDecoder().decode(AppVersionInfo.self, from: data)
            let local = currentVersion

            self.remoteVersion = remote
            self.lastCheckTime = Date()
            UserDefaults.standard.set(self.lastCheckTime, forKey: "rango_last_update_check")

            let isNewer = remote.build > local.build

            if isNewer {
                self.updateAvailable = true
                self.statusMessage = "Доступне оновлення: v\(remote.version)"

                if AppState.shared.autoUpdateEnabled {
                    NSLog("[Rango] New update detected (build %d > %d). Starting auto-update...", remote.build, local.build)
                    AppState.shared.showStatus("🦎 Оновлення Rango до v\(remote.version)...")
                    SoundEffect.shared.play("pop")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.performUpdate()
                    }
                } else if !silent {
                    AppState.shared.showStatus("🦎 Доступне оновлення v\(remote.version)!")
                }
            } else {
                self.updateAvailable = false
                self.statusMessage = "У вас найновіша версія (v\(local.version))"
            }
        } catch {
            NSLog("[Rango] Update check failed: %@", error.localizedDescription)
            self.statusMessage = silent ? "" : "Не вдалося перевірити оновлення"
        }

        isChecking = false
    }

    public func performUpdate() {
        guard !isUpdating else { return }
        isUpdating = true
        statusMessage = "Встановлення оновлення..."

        let script = """
        #!/bin/bash
        set -e
        LOG="/tmp/rango_update.log"
        echo "=== Rango Updater Started $(date) ===" > "$LOG"

        sleep 1

        ZIP_URL="https://github.com/ruslanower/rango/releases/latest/download/Rango.zip"
        TMP_ZIP="/tmp/Rango_latest.zip"
        TMP_DIR="/tmp/Rango_update_$$"

        if curl -sSfL "$ZIP_URL" -o "$TMP_ZIP" 2>>"$LOG" && [ -s "$TMP_ZIP" ]; then
            echo "Downloaded prebuilt release zip." >> "$LOG"
            rm -rf "$TMP_DIR"
            mkdir -p "$TMP_DIR"
            unzip -q -o "$TMP_ZIP" -d "$TMP_DIR" >> "$LOG" 2>&1
            
            if [ -d "$TMP_DIR/Rango.app" ]; then
                pkill -9 Rango 2>/dev/null || true
                rm -rf /Applications/Rango.app
                mv "$TMP_DIR/Rango.app" /Applications/Rango.app
                rm -rf "$TMP_DIR" "$TMP_ZIP"
                xattr -cr /Applications/Rango.app 2>/dev/null || true
                codesign -s - --force --deep /Applications/Rango.app 2>/dev/null || true
                echo "Successfully updated from prebuilt zip!" >> "$LOG"
                nohup /Applications/Rango.app/Contents/MacOS/Rango > /tmp/rango.log 2>&1 &
                exit 0
            fi
        fi

        echo "Falling back to install.sh build..." >> "$LOG"
        curl -sSL https://raw.githubusercontent.com/ruslanower/rango/main/install.sh | bash >> "$LOG" 2>&1
        """

        let scriptPath = "/tmp/rango_update.sh"
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            let perms: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
            try FileManager.default.setAttributes(perms, ofItemAtPath: scriptPath)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
            process.arguments = [scriptPath]
            try process.run()
            NSLog("[Rango] Update script launched detached: %@", scriptPath)
        } catch {
            NSLog("[Rango] Failed to launch update script: %@", error.localizedDescription)
            self.isUpdating = false
            self.statusMessage = "Помилка оновлення: \(error.localizedDescription)"
        }
    }
}
