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
}
