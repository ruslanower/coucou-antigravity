import AppKit
import Foundation

enum AntigravityBridge {
    static let bundleId = "com.google.antigravity"
    static let appPath = "/Applications/Antigravity.app"

    static func checkAndPromptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        if !isTrusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    static func getRunningAntigravity() -> NSRunningApplication? {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            return app
        }
        return NSWorkspace.shared.runningApplications.first {
            $0.localizedName == "Antigravity" || $0.localizedName == "Antigravity IDE"
        }
    }

    static func submitOption(index: Int) {
        let keyNum = "\(index + 1)"
        focusAntigravity {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let scriptSource = """
tell application "System Events"
    keystroke "\(keyNum)"
    delay 0.1
    key code 36
end tell
"""
                runAppleScript(scriptSource)
            }
        }
    }

    static func focusAntigravity(completion: (() -> Void)? = nil) {
        // 1. If already running, yield activation and bring to front
        if let runningApp = getRunningAntigravity() {
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: runningApp)
            }
            runningApp.activate()

            let bringFrontScript = """
tell application "System Events"
    try
        set frontmost of (first process whose bundle identifier is "\(bundleId)" or name is "Antigravity") to true
    end try
end tell
"""
            runAppleScript(bringFrontScript)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                completion?()
            }
            return
        }

        // 2. If not running, launch via NSWorkspace
        let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) ?? URL(fileURLWithPath: appPath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { app, error in
            if error != nil {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                proc.arguments = [appPath]
                try? proc.run()
            }
            if let completion = completion {
                // Give Electron window time to initialize
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    completion()
                }
            }
        }
    }

    static func launchIdeaInAntigravity(idea: StartupIdea) {
        checkAndPromptAccessibility()
        let prompt = """
Привіт! Почнімо роботу над новим мобільним застосунком: «\(idea.title)».

Категорія: \(idea.category)
Коротка концепція:
\(idea.description)

Зроби повний та глибокий аналіз цього продукту:
1. Детальний опис функціоналу та User Journey для користувача.
2. Цільова аудиторія (ЦА), ключові болі, сегменти та персонажі (User Personas).
3. Аналіз конкурентоспроможності: хто прямі та непрямі конкуренти, у чому наша головна відмінність (Unique Selling Proposition).
4. Бізнес-модель та монетизація: які ціни, тарифи, підписки або комісії використовувати, як на цьому заробляти.
5. Технічний стек (Frontend на Flutter/Swift, Backend, База даних, необхідні API).
6. Покроковий план розробки MVP від нуля до релізу.
"""

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)

        let isRunning = getRunningAntigravity() != nil
        let delayBeforePaste = isRunning ? 0.4 : 1.8

        focusAntigravity {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBeforePaste) {
                let scriptSource = """
tell application "System Events"
    try
        set appProc to (first process whose bundle identifier is "\(bundleId)" or name is "Antigravity")
        set frontmost of appProc to true
        delay 0.2
        try
            click menu item "New Conversation" of menu "File" of menu bar 1 of appProc
        on error
            keystroke "n" using command down
        end try
        delay 0.4
        keystroke "v" using command down
        delay 0.25
        key code 36
    end try
end tell
"""
                runAppleScript(scriptSource)
            }
        }
    }

    private static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInteractive).async {
            if let appleScript = NSAppleScript(source: source) {
                var errorDict: NSDictionary?
                appleScript.executeAndReturnError(&errorDict)
                if let err = errorDict {
                    NSLog("[TukTuk] AppleScript error: %@", err)
                }
            }
        }
    }
}
