import SwiftUI
import Combine

struct QuestionModel: Equatable {
    let question: String
    let options: [String]
}

enum NotchState: Equatable {
    case idle
    case status(String)
    case question(QuestionModel)

    var isExpanded: Bool {
        switch self {
        case .idle:
            return false
        case .status, .question:
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

    private var statusResetWorkItem: DispatchWorkItem?
    private var blinkTimer: AnyCancellable?

    private init() {
        startBlinkTimer()
    }

    private func startBlinkTimer() {
        blinkTimer = Timer.publish(every: 3.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.state == .idle else { return }
                self.isBlinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    self.isBlinking = false
                }
            }
    }

    func showQuestion(question: String, options: [String]) {
        statusResetWorkItem?.cancel()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            self.state = .question(QuestionModel(question: question, options: options))
        }
        SoundEffect.shared.playQuestion()
    }

    func showStatus(_ text: String, autoDismissAfter: Double = 3.5) {
        statusResetWorkItem?.cancel()
        if case .question = self.state {
            // Do not overwrite an active interactive question!
            return
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.state = .idle
        }
        SoundEffect.shared.playClose()
    }

    func selectOption(at index: Int) {
        SoundEffect.shared.playApprove()
        AntigravityBridge.submitOption(index: index)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.state = .idle
        }
    }
}
