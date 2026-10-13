import AppKit
import ApplicationServices
import Foundation

@MainActor
final class NotificationWatcher {
    static let shared = NotificationWatcher()

    private var timer: Timer?
    private var lastSeenDesc: String = ""
    private var lastNotificationTime: Date = .distantPast
    private var lastTelegramBadge: String = ""
    private var lastWhatsAppBadge: String = ""

    private init() {}

    func start() {
        NSLog("[Rango] NotificationWatcher starting background observation...")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
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
        if depth > 5 { return }
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
        var icon = "💬"
        var app = "Повідомлення"
        var isEnabled = true

        if fullLower.contains("telegram") {
            app = "Telegram"
            icon = "✈️"
            isEnabled = AppState.shared.notifyTelegram
        } else if fullLower.contains("whatsapp") {
            app = "WhatsApp"
            icon = "💬"
            isEnabled = AppState.shared.notifyWhatsApp
        } else if fullLower.contains("viber") {
            app = "Viber"
            icon = "💜"
            isEnabled = AppState.shared.notifyViber
        } else if fullLower.contains("пошта") || fullLower.contains("mail") {
            app = "Пошта"
            icon = "✉️"
            isEnabled = AppState.shared.notifyEmail
        } else if fullLower.contains("повідомлення") || fullLower.contains("messages") {
            app = "Повідомлення"
            icon = "💬"
            isEnabled = true
        } else if fullLower.contains("iphone") {
            app = "iPhone"
            icon = "📱"
            isEnabled = true
        } else {
            app = parts.first ?? "Сповіщення"
            icon = "🔔"
            isEnabled = AppState.shared.notifyBrowser
        }

        guard isEnabled else { return }

        var sender = "Нове повідомлення"
        var message = ""

        if parts.count >= 4 {
            sender = parts[2]
            message = parts[3...].joined(separator: ", ")
        } else if parts.count == 3 {
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

    // MARK: - 2. Dock Badge Inspection (Fallback when banners are disabled or silent)
    private func checkDockBadges() {
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

                var statusRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &statusRef)
                let badge = (statusRef as? String) ?? ""

                if title.localizedCaseInsensitiveContains("telegram") {
                    if !badge.isEmpty && badge != lastTelegramBadge && badge != "0" {
                        lastTelegramBadge = badge
                        if AppState.shared.notifyTelegram {
                            lastNotificationTime = Date()
                            NSLog("[Rango] Telegram dock badge increased to %@", badge)
                            AppState.shared.showPhoneNotification(
                                app: "Telegram",
                                icon: "✈️",
                                sender: "Telegram",
                                message: "Нове повідомлення (\(badge))"
                            )
                        }
                    } else if badge.isEmpty {
                        lastTelegramBadge = ""
                    }
                } else if title.localizedCaseInsensitiveContains("whatsapp") {
                    if !badge.isEmpty && badge != lastWhatsAppBadge && badge != "0" {
                        lastWhatsAppBadge = badge
                        if AppState.shared.notifyWhatsApp {
                            lastNotificationTime = Date()
                            NSLog("[Rango] WhatsApp dock badge increased to %@", badge)
                            AppState.shared.showPhoneNotification(
                                app: "WhatsApp",
                                icon: "💬",
                                sender: "WhatsApp",
                                message: "Нове повідомлення (\(badge))"
                            )
                        }
                    } else if badge.isEmpty {
                        lastWhatsAppBadge = ""
                    }
                }
            }
        }
    }
}
