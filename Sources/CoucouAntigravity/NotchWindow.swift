import AppKit
import SwiftUI
import Combine

final class NotchWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        self.isMovable = false
    }

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}

@MainActor
final class NotchWindowController: ObservableObject {
    static let shared = NotchWindowController()

    private var window: NotchWindow?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func setup() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else {
            return
        }

        let panelW: CGFloat = 520
        let panelH: CGFloat = 340
        let sf = screen.frame

        let rect = NSRect(
            x: sf.midX - panelW / 2,
            y: sf.maxY - panelH,
            width: panelW,
            height: panelH
        )

        let panel = NotchWindow(contentRect: rect)
        let hostingView = NSHostingView(rootView: NotchView())
        hostingView.frame = NSRect(origin: .zero, size: rect.size)
        panel.contentView = hostingView

        self.window = panel
        panel.orderFrontRegardless()

        // Observe state changes to adjust window interaction & size
        AppState.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak panel] state in
                guard let panel = panel else { return }
                guard let curScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
                let sf = curScreen.frame

                let targetW: CGFloat
                let targetH: CGFloat

                switch state {
                case .idle:
                    targetW = 200
                    targetH = 34
                case .status:
                    targetW = 320
                    targetH = 44
                case .question:
                    targetW = 500
                    targetH = 320
                }

                let newFrame = NSRect(
                    x: sf.midX - targetW / 2,
                    y: sf.maxY - targetH,
                    width: targetW,
                    height: targetH
                )
                panel.setFrame(newFrame, display: true, animate: false)
                panel.orderFrontRegardless()
            }
            .store(in: &cancellables)
    }
}
