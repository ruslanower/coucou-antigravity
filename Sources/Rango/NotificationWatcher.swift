import AppKit
import ApplicationServices
import Foundation

@MainActor
final class NotificationWatcher {
    static let shared = NotificationWatcher()

    private var timer: Timer?
    private var lastSeenDesc: String = ""
    private var lastNotificationTime: Date = .distantPast
    private var lastDockBadges: [String: String] = [:]

    private init() {}

    func start() {
        NSLog("[Rango] NotificationWatcher starting background observation for ALL notifications...")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemNotifications()
                self?.checkDockBadges()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 1. NotificationCenter.app Active Banners Inspection
    private func checkSystemNotifications() {
        guard AppState.shared.notifyAllSystemNotifications else { return }

        guard let nc = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.notificationcenterui" || $0.localizedName == "NotificationCenter"
        }) else { return }

        let app = AXUIElementCreateApplication(nc.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }

        for win in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? ""
            if title == "Notification Center" {
                findNotificationDesc(win)
            }
        }
    }

    private func findNotificationDesc(_ elem: AXUIElement, depth: Int = 0) {
        if depth > 6 { return }
        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXDescriptionAttribute as CFString, &descRef)
        if let desc = descRef as? String, !desc.isEmpty, desc.contains(",") {
            if desc != lastSeenDesc {
                lastSeenDesc = desc
                lastNotificationTime = Date()
                handleDetectedNotification(rawDesc: desc)
                return
            }
        }

        var cRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &cRef) == .success,
           let children = cRef as? [AXUIElement] {
            for c in children {
                findNotificationDesc(c, depth: depth + 1)
            }
        }
    }

    private func handleDetectedNotification(rawDesc: String) {
        let parts = rawDesc.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return }

        let fullLower = rawDesc.lowercased()
        var icon = "🔔"
        var app = "Сповіщення"

        // Smart app & icon detection for any macOS application
        if fullLower.contains("telegram") {
            app = "Telegram"
            icon = "✈️"
        } else if fullLower.contains("whatsapp") {
            app = "WhatsApp"
            icon = "💬"
        } else if fullLower.contains("viber") {
            app = "Viber"
            icon = "💜"
        } else if fullLower.contains("signal") {
            app = "Signal"
            icon = "🔵"
        } else if fullLower.contains("slack") {
            app = "Slack"
            icon = "💼"
        } else if fullLower.contains("discord") {
            app = "Discord"
            icon = "🎮"
        } else if fullLower.contains("пошта") || fullLower.contains("mail") {
            app = "Пошта"
            icon = "✉️"
        } else if fullLower.contains("календар") || fullLower.contains("calendar") {
            app = "Календар"
            icon = "📅"
        } else if fullLower.contains("нагадування") || fullLower.contains("reminders") {
            app = "Нагадування"
            icon = "⏰"
        } else if fullLower.contains("повідомлення") || fullLower.contains("messages") {
            app = "Повідомлення"
            icon = "💬"
        } else if fullLower.contains("safari") {
            app = "Safari"
            icon = "🧭"
        } else if fullLower.contains("chrome") {
            app = "Chrome"
            icon = "🌐"
        } else if fullLower.contains("arc") || fullLower.contains("edge") || fullLower.contains("firefox") {
            app = "Браузер"
            icon = "🌐"
        } else if fullLower.contains("музика") || fullLower.contains("music") || fullLower.contains("spotify") {
            app = "Музика"
            icon = "🎵"
        } else if fullLower.contains("нотатки") || fullLower.contains("notes") {
            app = "Нотатки"
            icon = "📝"
        } else if fullLower.contains("iphone") {
            app = "iPhone"
            icon = "📱"
        } else if fullLower.contains("finder") || fullLower.contains("airdrop") {
            app = "AirDrop"
            icon = "📡"
        } else if fullLower.contains("батарея") || fullLower.contains("battery") {
            app = "Батарея"
            icon = "🔋"
        } else {
            app = parts.first ?? "Сповіщення"
            icon = "🔔"
        }

        var sender = "Нове сповіщення"
        var message = ""

        if parts.count >= 4 {
            // [Source, App, Sender, Message] e.g. ["Script Editor", "Telegram", "Дмитро", "Привіт"]
            sender = parts[2]
            message = parts[3...].joined(separator: ", ")
        } else if parts.count == 3 {
            // [App, Sender, Message]
            sender = parts[1]
            message = parts[2]
        } else if parts.count == 2 {
            sender = parts[0]
            message = parts[1]
        } else {
            message = parts[0]
        }

        NSLog("[Rango] Real notification intercepted: app=%@ sender=%@ message=%@", app, sender, message)
        AppState.shared.showPhoneNotification(app: app, icon: icon, sender: sender, message: message)
    }

    // MARK: - 2. Dock Badge Inspection (For all running apps)
    private func checkDockBadges() {
        guard AppState.shared.notifyAllSystemNotifications else { return }
        // If a banner was recently detected in the last 3.5s, don't duplicate via badge
        if Date().timeIntervalSince(lastNotificationTime) < 3.5 { return }

        guard let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else { return }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var listRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &listRef) == .success,
              let children = listRef as? [AXUIElement] else { return }

        for child in children {
            var subChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subChildrenRef) == .success,
                  let dockItems = subChildrenRef as? [AXUIElement] else { continue }

            for item in dockItems {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String) ?? ""
                guard !title.isEmpty else { continue }

                var statusRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &statusRef)
                let badge = (statusRef as? String) ?? ""

                let lastBadge = lastDockBadges[title] ?? ""
                if !badge.isEmpty && badge != lastBadge && badge != "0" {
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
                    else { icon = "🔔" }

                    AppState.shared.showPhoneNotification(
                        app: title,
                        icon: icon,
                        sender: title,
                        message: "Нове повідомлення (\(badge))"
                    )
                } else if badge.isEmpty {
                    lastDockBadges[title] = ""
                }
            }
        }
    }
}
