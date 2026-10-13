import SwiftUI
import AppKit

@main
struct CoucouAntigravityApp: App {
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
        NSLog("[CoucouAntigravity] Launched successfully via SwiftUI!")
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "🔮"
            button.toolTip = "Coucou Antigravity Companion"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Coucou Antigravity (Активний)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let testItem = NSMenuItem(title: "Тестовий запит у чілку...", action: #selector(testQuestion), keyEquivalent: "t")
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

    @objc private func testQuestion() {
        Task { @MainActor in
            AppState.shared.showQuestion(
                question: "Тестовий запит: чи все зручно працює в чілці?",
                options: [
                    "(Рекомендовано) Так, все супер!",
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
