import AppKit
import Foundation

@MainActor
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
            "/Applications/Rango.app/Contents/Resources/sounds",
            "/Applications/TukTuk.app/Contents/Resources/sounds",
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
        guard AppState.shared.soundEnabled else { return }
        let volume = Float(AppState.shared.soundVolume)

        if let sound = sounds[name] {
            sound.volume = volume
            sound.stop()
            sound.play()
        } else if let fallback = NSSound(named: "Pop") {
            fallback.volume = volume
            fallback.play()
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
