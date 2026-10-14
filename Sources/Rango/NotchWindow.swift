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
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingAreaRef = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let state = AppState.shared.state
        let topY = self.frame.height
        let centerDist = abs(point.x - (self.frame.width / 2))

        switch state {
        case .idle:
            let inZone = point.y >= (topY - 48) && centerDist <= 130
            if inZone {
                AppState.shared.openHoverDrawer()
            }

        case .status:
            let inZone = point.y >= (topY - 48) && centerDist <= 200
            if inZone {
                AppState.shared.openHoverDrawer()
            }

        case .notification:
            let inZone = point.y >= (topY - 80) && centerDist <= 220
            if inZone {
                AppState.shared.pauseNotificationDismiss()
            } else {
                AppState.shared.resumeNotificationDismiss(delay: 2.0)
            }

        case .hoverDrawer:
            let inZone = point.y >= (topY - 180) && centerDist <= 265
            if inZone {
                AppState.shared.cancelScheduledCloseHover()
            } else {
                AppState.shared.scheduleCloseHoverDrawer(delay: 0.35)
            }

        default:
            break
        }
    }

    override func mouseExited(with event: NSEvent) {
        if AppState.shared.state == .hoverDrawer {
            AppState.shared.scheduleCloseHoverDrawer(delay: 0.35)
        } else if case .notification = AppState.shared.state {
            AppState.shared.resumeNotificationDismiss(delay: 2.0)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        let state = AppState.shared.state
        let topY = self.frame.height
        let centerDist = abs(point.x - (self.frame.width / 2))

        switch state {
        case .idle:
            let inZone = point.y >= (topY - 48) && centerDist <= 130
            return inZone ? view : nil

        case .status:
            let inZone = point.y >= (topY - 48) && centerDist <= 200
            return inZone ? view : nil

        case .hoverDrawer:
            let inZone = point.y >= (topY - 180) && centerDist <= 265
            return inZone ? view : nil

        case .question:
            let inZone = point.y >= (topY - 360) && centerDist <= 260
            return inZone ? view : nil

        case .notification:
            let inZone = point.y >= (topY - 80) && centerDist <= 220
            return inZone ? view : nil
        }
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

        NSLog("[Rango] NotchWindowController initialized on screen: %@ frame: %@", screen.localizedName, NSStringFromRect(rect))
    }
}
