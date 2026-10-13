import SwiftUI
import AppKit

@main
struct RangoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        checkAccessibilityPermissions()
        SocketServer.shared.start()
        NotchWindowController.shared.setup()
        UpdateManager.shared.startPeriodicCheck()
        NSLog("[Rango] Launched successfully via SwiftUI!")
    }

    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        NSLog("[Rango] Accessibility status: %d", isTrusted ? 1 : 0)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "🦎"
            button.toolTip = "«Rango» — ШІ-помічник для Antigravity"
        }

        let menu = NSMenu()
        let ver = UpdateManager.shared.currentVersion.version
        menu.addItem(NSMenuItem(title: "Rango v\(ver) (Активний)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Налаштування...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "Перевірити оновлення...", action: #selector(checkUpdates), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        let testItem = NSMenuItem(title: "Тестовий запит у чілку", action: #selector(testQuestion), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)

        let openAgItem = NSMenuItem(title: "Фокус на Antigravity", action: #selector(openAntigravity), keyEquivalent: "a")
        openAgItem.target = self
        menu.addItem(openAgItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Вийти", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    @objc private func checkUpdates() {
        Task { @MainActor in
            await UpdateManager.shared.checkForUpdates(silent: false)
        }
    }

    @objc private func openSettings() {
        Task { @MainActor in
            AppState.shared.openSettingsWindow()
        }
    }

    @objc private func testQuestion() {
        Task { @MainActor in
            AppState.shared.showQuestion(
                question: "Тестовий запит: чи все зручно працює в чілці «Rango»?",
                options: [
                    "(Рекомендовано) Так, Rango працює ідеально!",
                    "Варіант 2: Перевірка звʼязку",
                    "Варіант 3: Тест кнопки"
                ]
            )
        }
    }

    @objc private func openAntigravity() {
        AntigravityBridge.focusAntigravity()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
