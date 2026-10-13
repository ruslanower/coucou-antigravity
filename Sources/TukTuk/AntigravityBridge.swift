import AppKit
import Foundation
import CoreGraphics

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

    static func getAntigravityWindowBounds() -> CGRect? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for win in windowList {
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            if owner == "Antigravity" {
                if let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                   let x = boundsDict["X"] as? CGFloat,
                   let y = boundsDict["Y"] as? CGFloat,
                   let w = boundsDict["Width"] as? CGFloat,
                   let h = boundsDict["Height"] as? CGFloat,
                   w > 400 && h > 300 {
                    return CGRect(x: x, y: y, width: w, height: h)
                }
            }
        }
        return nil
    }

    static func simulateClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(40000)
        up?.post(tap: .cghidEventTap)
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

        focusAntigravity {
            waitForWindow(maxAttempts: isRunning ? 8 : 16, delay: 0.2) { bounds in
                guard let bounds = bounds else {
                    fallbackPasteAndSend()
                    return
                }

                // 1. Клік на кнопку "+ New Conversation" (зверху зліва сайдбару)
                let newConvPoint = CGPoint(x: bounds.origin.x + 90, y: bounds.origin.y + 70)
                simulateClick(at: newConvPoint)

                // 2. Очікуємо перемикання на нову розмову
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    // 3. Клік у центр поля введення нового діалогу
                    let inputPoint = CGPoint(x: bounds.origin.x + bounds.width * 0.5, y: bounds.origin.y + 380)
                    simulateClick(at: inputPoint)

                    // 4. Додатково фокусуємо через Cmd+L та вставляємо промпт
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        let script = """
tell application "System Events"
    launch
    try
        set frontmost of (first process whose name is "Antigravity") to true
    end try
    delay 0.1
    keystroke "l" using command down
    delay 0.15
    keystroke "v" using command down
    delay 0.25
    keystroke return using command down
    delay 0.15
    key code 36
end tell
"""
                        runAppleScript(script)
                    }
                }
            }
        }
    }

    private static func waitForWindow(maxAttempts: Int, delay: Double, completion: @escaping (CGRect?) -> Void) {
        var attempts = 0
        func check() {
            if let bounds = getAntigravityWindowBounds() {
                completion(bounds)
                return
            }
            attempts += 1
            if attempts < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    check()
                }
            } else {
                completion(nil)
            }
        }
        check()
    }

    private static func fallbackPasteAndSend() {
        let scriptSource = """
tell application "System Events"
    launch
    try
        set frontmost of (first process whose name is "Antigravity") to true
    end try
    delay 0.2
    keystroke "l" using command down
    delay 0.15
    keystroke "v" using command down
    delay 0.25
    keystroke return using command down
    delay 0.15
    key code 36
end tell
"""
        runAppleScript(scriptSource)
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
