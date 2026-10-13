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

final class NotchContainerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        // If idle, pass clicks through unless clicking directly on either wing
        if AppState.shared.state == .idle {
            let topY = self.frame.height
            let inMenuY = point.y >= (topY - 32)
            guard inMenuY else { return nil }
            let centerDist = abs(point.x - (self.frame.width / 2))
            let inWings = centerDist >= 118 && centerDist <= 230
            return inWings ? view : nil
        }
        return view
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

        let topInset = screen.safeAreaInsets.top
        AppState.shared.notchHeight = topInset > 0 ? topInset : 34

        let panelW: CGFloat = 600
        let panelH: CGFloat = 420
        let sf = screen.frame

        let rect = NSRect(
            x: sf.midX - panelW / 2,
            y: sf.maxY - panelH,
            width: panelW,
            height: panelH
        )

        let panel = NotchWindow(contentRect: rect)
        let container = NotchContainerView(frame: NSRect(origin: .zero, size: rect.size))
        container.autoresizingMask = [.width, .height]

        let hostingView = NSHostingView(rootView: NotchView())
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        panel.contentView = container
        self.window = panel
        panel.orderFrontRegardless()

        AppState.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak panel] _ in
                panel?.orderFrontRegardless()
            }
            .store(in: &cancellables)

        NSLog("[CoucouAntigravity] NotchWindowController initialized on screen: %@ frame: %@", screen.localizedName, NSStringFromRect(rect))
    }
}
