import AppKit
import Foundation

final class SoundEffect {
    static let shared = SoundEffect()
    private var sounds: [String: NSSound] = [:]

    private init() {
        preloadSounds()
    }

    private func preloadSounds() {
        let possibleDirs = [
            Bundle.main.resourcePath.map { $0 + "/sounds" },
            Bundle.main.resourcePath,
            "/Applications/CoucouAntigravity.app/Contents/Resources/sounds",
            NSString("~/Library/Application Support/NotchBuddy/sounds").expandingTildeInPath,
            NSString("~/.coucou-antigravity/sounds").expandingTildeInPath
        ].compactMap { $0 }

        for dir in possibleDirs {
            guard FileManager.default.fileExists(atPath: dir) else { continue }
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files where file.hasSuffix(".wav") {
                    let name = (file as NSString).deletingPathExtension
                    let fullPath = (dir as NSString).appendingPathComponent(file)
                    if sounds[name] == nil, let sound = NSSound(contentsOfFile: fullPath, byReference: true) {
                        sounds[name] = sound
                    }
                }
            }
        }
    }

    func play(_ name: String) {
        if let sound = sounds[name] {
            sound.stop()
            sound.play()
        } else {
            // Fallback system beep / sound
            NSSound(named: "Pop")?.play()
        }
    }

    func playQuestion() {
        play("question")
    }

    func playApprove() {
        play("approve")
    }

    func playClose() {
        play("close")
    }
}
