import SwiftUI
import Combine

struct QuestionModel: Equatable {
    let question: String
    let options: [String]
}

enum NotchState: Equatable {
    case idle
    case hoverDrawer
    case status(String)
    case question(QuestionModel)

    var isExpanded: Bool {
        switch self {
        case .idle:
            return false
        case .hoverDrawer, .status, .question:
            return true
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var state: NotchState = .idle
    @Published var isBlinking: Bool = false
    @Published var notchHeight: CGFloat = 34

    // MARK: - Settings Properties (with UserDefaults Persistence)
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "tuktuk_soundEnabled") }
    }
    @Published var soundVolume: Double {
        didSet { UserDefaults.standard.set(soundVolume, forKey: "tuktuk_soundVolume") }
    }
    @Published var autoCloseSeconds: Int {
        didSet { UserDefaults.standard.set(autoCloseSeconds, forKey: "tuktuk_autoCloseSeconds") }
    }
    @Published var hoverExpandEnabled: Bool {
        didSet { UserDefaults.standard.set(hoverExpandEnabled, forKey: "tuktuk_hoverExpandEnabled") }
    }

    // Notification Toggles
    @Published var notifyTelegram: Bool {
        didSet { UserDefaults.standard.set(notifyTelegram, forKey: "tuktuk_notifyTelegram") }
    }
    @Published var notifyWhatsApp: Bool {
        didSet { UserDefaults.standard.set(notifyWhatsApp, forKey: "tuktuk_notifyWhatsApp") }
    }
    @Published var notifyViber: Bool {
        didSet { UserDefaults.standard.set(notifyViber, forKey: "tuktuk_notifyViber") }
    }
    @Published var notifyEmail: Bool {
        didSet { UserDefaults.standard.set(notifyEmail, forKey: "tuktuk_notifyEmail") }
    }
    @Published var notifyBrowser: Bool {
        didSet { UserDefaults.standard.set(notifyBrowser, forKey: "tuktuk_notifyBrowser") }
    }

    private var statusResetWorkItem: DispatchWorkItem?
    private var questionTimeoutWorkItem: DispatchWorkItem?
    private var hoverCloseWorkItem: DispatchWorkItem?
    private var blinkTimer: AnyCancellable?

    private init() {
        let ud = UserDefaults.standard
        self.soundEnabled = ud.object(forKey: "tuktuk_soundEnabled") != nil ? ud.bool(forKey: "tuktuk_soundEnabled") : true
        self.soundVolume = ud.object(forKey: "tuktuk_soundVolume") != nil ? ud.double(forKey: "tuktuk_soundVolume") : 0.8
        self.autoCloseSeconds = ud.object(forKey: "tuktuk_autoCloseSeconds") != nil ? ud.integer(forKey: "tuktuk_autoCloseSeconds") : 120
        self.hoverExpandEnabled = ud.object(forKey: "tuktuk_hoverExpandEnabled") != nil ? ud.bool(forKey: "tuktuk_hoverExpandEnabled") : true

        self.notifyTelegram = ud.bool(forKey: "tuktuk_notifyTelegram")
        self.notifyWhatsApp = ud.bool(forKey: "tuktuk_notifyWhatsApp")
        self.notifyViber = ud.bool(forKey: "tuktuk_notifyViber")
        self.notifyEmail = ud.bool(forKey: "tuktuk_notifyEmail")
        self.notifyBrowser = ud.bool(forKey: "tuktuk_notifyBrowser")

        startBlinkTimer()
    }

    private func startBlinkTimer() {
        blinkTimer = Timer.publish(every: 3.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isBlinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    self.isBlinking = false
                }
            }
    }

    // MARK: - Notch Actions
    func openHoverDrawer() {
        guard hoverExpandEnabled else { return }
        hoverCloseWorkItem?.cancel()
        if case .question = state { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.state = .hoverDrawer
        }
    }

    func scheduleCloseHoverDrawer(delay: Double = 0.35) {
        hoverCloseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.state == .hoverDrawer {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    self.state = .idle
                }
            }
        }
        hoverCloseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelScheduledCloseHover() {
        hoverCloseWorkItem?.cancel()
    }

    func showQuestion(question: String, options: [String]) {
        statusResetWorkItem?.cancel()
        questionTimeoutWorkItem?.cancel()
        hoverCloseWorkItem?.cancel()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            self.state = .question(QuestionModel(question: question, options: options))
        }
        SoundEffect.shared.playQuestion()

        if autoCloseSeconds > 0 {
            let timeout = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if case .question = self.state {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        self.state = .idle
                    }
                    SoundEffect.shared.playClose()
                }
            }
            questionTimeoutWorkItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(autoCloseSeconds), execute: timeout)
        }
    }

    func showStatus(_ text: String, autoDismissAfter: Double = 3.5) {
        statusResetWorkItem?.cancel()
        if case .question = self.state {
            return // Do not overwrite an active interactive question
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.state = .status(text)
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if case .status = self.state {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    self.state = .idle
                }
            }
        }
        statusResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter, execute: work)
    }

    func close() {
        statusResetWorkItem?.cancel()
        questionTimeoutWorkItem?.cancel()
        hoverCloseWorkItem?.cancel()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.state = .idle
        }
        SoundEffect.shared.playClose()
    }

    func selectOption(at index: Int) {
        SoundEffect.shared.playApprove()
        AntigravityBridge.submitOption(index: index)
        questionTimeoutWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.state = .idle
        }
    }

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
