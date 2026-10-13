import SwiftUI
import AppKit

@main
struct TukTukApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        SocketServer.shared.start()
        NotchWindowController.shared.setup()
        NSLog("[TukTuk] Launched successfully via SwiftUI!")
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "🔮"
            button.toolTip = "«Тук-тук» — Antigravity Помічник"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Тук-тук v1.0.0 (Активний)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Налаштування...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    @objc private func openSettings() {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }

    @objc private func testQuestion() {
        Task { @MainActor in
            AppState.shared.showQuestion(
                question: "Тестовий запит: чи все зручно працює в чілці «Тук-тук»?",
                options: [
                    "(Рекомендовано) Так, все працює ідеально!",
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
