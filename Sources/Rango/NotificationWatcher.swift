import AppKit
import ApplicationServices
import Foundation

@MainActor
final class NotificationWatcher {
    static let shared = NotificationWatcher()

    private var timer: Timer?
    private var currentBannerFingerprint: String?
    private var lastNotificationTime: Date = .distantPast
    private var lastDockBadges: [String: String] = [:]

    private init() {}

    func start() {
        NSLog("[Rango] NotificationWatcher starting background observation for ALL notifications...")
        timer?.invalidate()
        let t = Timer(timeInterval: 0.30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemNotifications()
                self?.checkDockBadges()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 1. NotificationCenter.app Active Banners Inspection
    private func checkSystemNotifications() {
        guard AppState.shared.notifyAllSystemNotifications else { return }

        guard let nc = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.notificationcenterui" ||
            $0.localizedName == "NotificationCenter" ||
            $0.localizedName == "Центр сповіщень"
        }) else { return }

        let app = AXUIElementCreateApplication(nc.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }

        var foundBannerInThisCycle = false
        for win in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? ""
            if title == "Список" || title == "На черзі" || title.contains("Batteries") || title.contains("Widget") {
                continue
            }

            var texts = extractTexts(win)
            if texts.isEmpty {
                if let fallbackDesc = findDescription(win), !fallbackDesc.isEmpty {
                    texts = fallbackDesc.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }

            if !texts.isEmpty {
                foundBannerInThisCycle = true
                processBannerTexts(texts)
                break
            }
        }

        if !foundBannerInThisCycle {
            self.currentBannerFingerprint = nil
        }
    }

    private func extractTexts(_ elem: AXUIElement, depth: Int = 0) -> [String] {
        if depth > 8 { return [] }
        var results: [String] = []

        var valRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valRef)
        if let v = valRef as? String {
            let clean = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && !clean.contains("Увесь день") && !clean.contains("Заряджено") {
                results.append(clean)
            }
        }

        var cRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &cRef) == .success,
           let children = cRef as? [AXUIElement] {
            for c in children {
                results.append(contentsOf: extractTexts(c, depth: depth + 1))
            }
        }
        return results
    }

    private func findDescription(_ elem: AXUIElement, depth: Int = 0) -> String? {
        if depth > 6 { return nil }
        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXDescriptionAttribute as CFString, &descRef)
        if let desc = descRef as? String, !desc.isEmpty, desc.contains(",") {
            return desc
        }
        var cRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &cRef) == .success,
           let children = cRef as? [AXUIElement] {
            for c in children {
                if let found = findDescription(c, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }

    private func processBannerTexts(_ rawTexts: [String]) {
        var clean = rawTexts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !clean.isEmpty else { return }

        // Remove script wrappers if invoked via AppleScript
        if clean.first == "Редактор скриптів" || clean.first == "Script Editor" {
            clean.removeFirst()
        }

        var isIPhoneMirroring = false
        if clean.first == "Дублювання iPhone" || clean.first == "iPhone Mirroring" || clean.first == "iPhone" {
            isIPhoneMirroring = true
            clean.removeFirst()
        }

        var rawApp = "Сповіщення"
        var sender = "Нове повідомлення"
        var message = ""

        if clean.count >= 3 {
            rawApp = clean[0]
            sender = clean[1]
            message = clean[2...].joined(separator: " ")
        } else if clean.count == 2 {
            rawApp = clean[0]
            sender = clean[1]
            message = ""
        } else if clean.count == 1 {
            sender = clean[0]
            message = ""
        }

        let displayApp = isIPhoneMirroring ? "\(rawApp) (iPhone)" : rawApp
        let fingerprint = "\(displayApp)|\(sender)|\(message)"

        if fingerprint == currentBannerFingerprint {
            return
        }

        currentBannerFingerprint = fingerprint
        lastNotificationTime = Date()

        let fullLower = (displayApp + " " + sender).lowercased()
        var icon = "🔔"

        if fullLower.contains("telegram") {
            icon = "✈️"
        } else if fullLower.contains("whatsapp") {
            icon = "💬"
        } else if fullLower.contains("viber") {
            icon = "💜"
        } else if fullLower.contains("signal") {
            icon = "🔵"
        } else if fullLower.contains("slack") {
            icon = "💼"
        } else if fullLower.contains("discord") {
            icon = "🎮"
        } else if fullLower.contains("пошта") || fullLower.contains("mail") {
            icon = "✉️"
        } else if fullLower.contains("календар") || fullLower.contains("calendar") {
            icon = "📅"
        } else if fullLower.contains("нагадування") || fullLower.contains("reminders") {
            icon = "⏰"
        } else if fullLower.contains("повідомлення") || fullLower.contains("messages") {
            icon = "💬"
        } else if fullLower.contains("safari") || fullLower.contains("chrome") || fullLower.contains("arc") || fullLower.contains("edge") {
            icon = "🌐"
        } else if fullLower.contains("нотатки") || fullLower.contains("notes") {
            icon = "📝"
        } else if fullLower.contains("музика") || fullLower.contains("music") || fullLower.contains("spotify") {
            icon = "🎵"
        } else if isIPhoneMirroring || fullLower.contains("iphone") {
            icon = "📱"
        } else if fullLower.contains("airdrop") || fullLower.contains("finder") {
            icon = "📡"
        } else {
            icon = "🔔"
        }

        NSLog("[Rango] Real notification intercepted: app=%@ sender=%@ message=%@", displayApp, sender, message)
        AppState.shared.showPhoneNotification(app: displayApp, icon: icon, sender: sender, message: message)
    }

    // MARK: - 2. Dock Badge Inspection (For running apps)
    private func checkDockBadges() {
        guard AppState.shared.notifyAllSystemNotifications else { return }
        // If a banner was recently detected in the last 3.5s, don't duplicate via badge
        if Date().timeIntervalSince(lastNotificationTime) < 3.5 { return }

        guard let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else { return }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var listRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &listRef) == .success,
              let children = listRef as? [AXUIElement] else { return }

        checkDockChildren(children)
    }

    private func checkDockChildren(_ elements: [AXUIElement]) {
        for item in elements {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? ""

            var statusRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &statusRef)
            let badge = (statusRef as? String) ?? ""

            if !title.isEmpty && !badge.isEmpty {
                let lastBadge = lastDockBadges[title] ?? ""
                if badge != lastBadge && badge != "0" {
                    lastDockBadges[title] = badge
                    lastNotificationTime = Date()
                    NSLog("[Rango] Dock badge changed for %@: %@", title, badge)

                    var icon = "💬"
                    let lower = title.lowercased()
                    if lower.contains("telegram") { icon = "✈️" }
                    else if lower.contains("whatsapp") { icon = "💬" }
                    else if lower.contains("mail") || lower.contains("пошта") { icon = "✉️" }
                    else if lower.contains("slack") { icon = "💼" }
                    else if lower.contains("discord") { icon = "🎮" }
                    else if lower.contains("viber") { icon = "💜" }
                    else if lower.contains("дублювання iphone") { icon = "📱" }
                    else { icon = "🔔" }

                    AppState.shared.showPhoneNotification(
                        app: title,
                        icon: icon,
                        sender: title,
                        message: "Нове повідомлення (\(badge))"
                    )
                }
            } else if !title.isEmpty && badge.isEmpty {
                lastDockBadges[title] = ""
            }

            var cRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &cRef) == .success,
               let subChildren = cRef as? [AXUIElement] {
                checkDockChildren(subChildren)
            }
        }
    }
}
