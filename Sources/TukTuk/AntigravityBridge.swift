import AppKit
import Foundation

enum AntigravityBridge {
    static func submitOption(index: Int) {
        let keyNum = "\(index + 1)"
        let scriptSource = """
tell application "Antigravity" to activate
delay 0.15
tell application "System Events"
    keystroke "\(keyNum)"
    delay 0.1
    key code 36
end tell
"""
        DispatchQueue.global(qos: .userInteractive).async {
            if let appleScript = NSAppleScript(source: scriptSource) {
                var errorDict: NSDictionary?
                appleScript.executeAndReturnError(&errorDict)
                if let error = errorDict {
                    NSLog("[TukTuk] AppleScript error: %@", error)
                }
            }
        }
    }

    static func focusAntigravity() {
        let scriptSource = """
tell application "Antigravity" to activate
"""
        DispatchQueue.global(qos: .userInteractive).async {
            if let appleScript = NSAppleScript(source: scriptSource) {
                var errorDict: NSDictionary?
                appleScript.executeAndReturnError(&errorDict)
            }
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

        let scriptSource = """
tell application "Antigravity" to activate
delay 0.35
tell application "System Events"
    keystroke "n" using command down
    delay 0.4
    keystroke "v" using command down
    delay 0.25
    key code 36
end tell
"""
        DispatchQueue.global(qos: .userInteractive).async {
            if let appleScript = NSAppleScript(source: scriptSource) {
                var errorDict: NSDictionary?
                appleScript.executeAndReturnError(&errorDict)
                if let error = errorDict {
                    NSLog("[TukTuk] launchIdea error: %@", error)
                }
            }
        }
    }
}
