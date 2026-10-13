import AppKit
import Foundation

enum AntigravityBridge {
    static let appPath = "/Applications/Antigravity.app"

    static func focusAntigravity(completion: (() -> Void)? = nil) {
        // 1. Unhide and activate if running
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.google.antigravity" || $0.localizedName == "Antigravity"
        }) {
            app.unhide()
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        // 2. Launch or bring to front via /usr/bin/open
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = [appPath]
        try? proc.run()

        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }

    static func submitOption(index: Int) {
        let keyNum = "\(index + 1)"
        focusAntigravity {
            let scriptSource = """
tell application "System Events"
    launch
    try
        set frontmost of (first process whose name is "Antigravity") to true
    end try
    delay 0.15
    keystroke "\(keyNum)"
    delay 0.1
    key code 36
end tell
"""
            runAppleScript(scriptSource)
        }
    }

    static func launchIdeaInAntigravity(idea: StartupIdea) {
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

        let isRunning = NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == "com.google.antigravity" || $0.localizedName == "Antigravity"
        })
        let delayBeforePaste = isRunning ? 0.35 : 1.8

        focusAntigravity {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBeforePaste) {
                let scriptSource = """
tell application "System Events"
    launch
    try
        set frontmost of (first process whose name is "Antigravity") to true
    end try
    delay 0.25
    try
        click menu item "New Conversation" of menu "File" of menu bar 1 of (first process whose name is "Antigravity")
    on error
        keystroke "n" using command down
    end try
    delay 0.45
    keystroke "v" using command down
    delay 0.25
    key code 36
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
