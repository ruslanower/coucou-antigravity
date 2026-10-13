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
            let inNotchZone = point.y >= (topY - 36) && centerDist <= 110
            if inNotchZone {
                AppState.shared.openHoverDrawer()
            }

        case .hoverDrawer:
            let inDrawerZone = point.y >= (topY - 155) && centerDist <= 260
            if inDrawerZone {
                AppState.shared.cancelScheduledCloseHover()
            } else {
                AppState.shared.scheduleCloseHoverDrawer()
            }

        default:
            break
        }
    }

    override func mouseExited(with event: NSEvent) {
        if AppState.shared.state == .hoverDrawer {
            AppState.shared.scheduleCloseHoverDrawer()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        let state = AppState.shared.state
        let topY = self.frame.height
        let centerDist = abs(point.x - (self.frame.width / 2))

        switch state {
        case .idle:
            let inNotchZone = point.y >= (topY - 36) && centerDist <= 110
            return inNotchZone ? view : nil

        case .hoverDrawer:
            let inDrawerZone = point.y >= (topY - 155) && centerDist <= 260
            return inDrawerZone ? view : nil

        case .question:
            let inQuestionZone = point.y >= (topY - 390) && centerDist <= 255
            return inQuestionZone ? view : nil

        case .status:
            let inStatusZone = point.y >= (topY - 38) && centerDist <= 140
            return inStatusZone ? view : nil
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
