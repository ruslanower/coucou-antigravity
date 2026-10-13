import SwiftUI
import AppKit

// MARK: - Головний контейнер чілки (Rango Notch View)
public struct NotchView: View {
    @ObservedObject var appState = AppState.shared
    @State private var currentIdea: StartupIdea? = ProjectIdeaGenerator.shared.generateNextIdea()

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            switch appState.state {
            case .idle:
                NotchPillView(appState: appState)
                    .frame(width: 190, height: 30)
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .hoverDrawer:
                NotchDrawerView(appState: appState, currentIdea: $currentIdea)
                    .frame(width: 490, height: 160)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
            case .status(let message):
                NotchStatusPillView(message: message)
                    .frame(minWidth: 220, maxWidth: 350)
                    .frame(height: 30)
                    .padding(.top, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .question(let question):
                NotchQuestionCardView(question: question) { index in
                    appState.selectOption(at: index)
                }
                .frame(width: 460)
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 0)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: appState.state)
    }
}

// MARK: - 1. Idle Notch Pill (Компактна чілка з персонажем Rango)
struct NotchPillView: View {
    @ObservedObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Rango хамелеон
            RangoAvatarView(size: 20)
                .frame(width: 24, height: 22)

            Text("Rango")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                    .shadow(color: Color.green.opacity(0.8), radius: 2)
                Text("ШІ активний")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.6), Color.teal.opacity(0.3), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 6, y: 2)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHovered = hovering
            }
            if hovering {
                appState.openHoverDrawer()
            }
        }
        .onTapGesture {
            appState.openHoverDrawer()
            SoundEffect.shared.play("greet")
        }
    }
}

// MARK: - Статус-пілл
struct NotchStatusPillView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            RangoAvatarView(size: 20)
                .frame(width: 24, height: 22)

            Text(message)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(1)

            Spacer()

            Circle()
                .fill(Color.green)
                .frame(width: 5, height: 5)
                .shadow(color: Color.green.opacity(0.8), radius: 2)
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.6), Color.teal.opacity(0.3), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 6, y: 2)
        )
    }
}

// MARK: - 2. Розгорнута шторка (Notch Drawer з двома картками)
struct NotchDrawerView: View {
    @ObservedObject var appState: AppState
    @Binding var currentIdea: StartupIdea?

    var body: some View {
        VStack(spacing: 8) {
            // Верхній бар керування
            HStack(spacing: 12) {
                // Лівий блок: навігаційні кнопки
                HStack(spacing: 14) {
                    Button(action: {
                        SoundEffect.shared.play("greet")
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        AntigravityBridge.focusAntigravity()
                    }) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Фокус на Antigravity")

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            currentIdea = ProjectIdeaGenerator.shared.generateNextIdea()
                        }
                        SoundEffect.shared.play("pop")
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Згенерувати нову ідею")
                }

                Spacer()

                // Правий блок: ⚙️ 🔊
                HStack(spacing: 12) {
                    Button(action: {
                        appState.openSettingsWindow()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .help("Налаштування «Rango»")

                    Button(action: {
                        appState.soundEnabled.toggle()
                        if appState.soundEnabled {
                            SoundEffect.shared.play("greet")
                        }
                    }) {
                        Image(systemName: appState.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(appState.soundEnabled ? .white.opacity(0.85) : .white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .help(appState.soundEnabled ? "Вимкнути звук" : "Увімкнути звук")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // Нижня частина: 2 великі картки поруч
            HStack(spacing: 10) {
                // Картка 1: Rango + Відкрити Antigravity
                Button(action: {
                    AntigravityBridge.focusAntigravity()
                    SoundEffect.shared.play("peek")
                    appState.close()
                }) {
                    HStack(spacing: 10) {
                        RangoAvatarView(size: 42)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Відкрити Antigravity")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Text("Rango • Швидкий запуск")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Картка 2: Динамічний генератор ідей на основі проєктів Antigravity
                if let idea = currentIdea {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(idea.category)
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.green.opacity(0.2)))
                                .lineLimit(1)

                            Spacer()

                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    currentIdea = nil
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(idea.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(idea.description)
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 6) {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                    currentIdea = ProjectIdeaGenerator.shared.generateNextIdea()
                                }
                                SoundEffect.shared.play("blip")
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "dice.fill")
                                        .font(.system(size: 8))
                                    Text("Нова ідея")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                )
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                AntigravityBridge.launchIdeaInAntigravity(idea: idea)
                                SoundEffect.shared.play("approve")
                                appState.close()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 8))
                                    Text("Втілити ідею 🚀")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [Color.green.opacity(0.8), Color.teal],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.09))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.green.opacity(0.4), lineWidth: 1)
                            )
                    )
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            currentIdea = ProjectIdeaGenerator.shared.generateNextIdea()
                        }
                        SoundEffect.shared.play("pop")
                    }) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.green.opacity(0.8), Color.teal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.yellow)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Згенерувати ідею")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("За твоїми проєктами в Antigravity 🎲")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(width: 490, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.5), Color.teal.opacity(0.3), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.6), radius: 20, y: 10)
        .onHover { hovering in
            if hovering {
                appState.cancelScheduledCloseHover()
            } else {
                appState.scheduleCloseHoverDrawer()
            }
        }
    }
}

// MARK: - 3. Інтерактивна картка запитання (Question Card)
struct NotchQuestionCardView: View {
    let question: QuestionModel
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RangoAvatarView(size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Запитання від Antigravity")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                    Text(question.question)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                Spacer()

                Button(action: {
                    AppState.shared.close()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(5)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 6) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        onSelect(index)
                    }) {
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color.white.opacity(0.12)))

                            Text(option)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Rango Avatar View (Офіційний персонаж Rango)
public struct RangoAvatarView: View {
    public let size: CGFloat
    @State private var breathing: Bool = false

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            if let nsImg = loadRangoImage() {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size * 1.1)
                    .scaleEffect(breathing ? 1.03 : 0.97)
                    .offset(y: breathing ? -0.8 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                        value: breathing
                    )
                    .onAppear {
                        breathing = true
                    }
            } else {
                Text("🦎")
                    .font(.system(size: size * 0.75))
            }
        }
        .frame(width: size, height: size)
    }

    private func loadRangoImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "rango", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let fallbackPaths = [
            "/Applications/Rango.app/Contents/Resources/rango.png",
            "Resources/rango.png",
            "/Users/ruslanbarbutsa/.gemini/antigravity/scratch/coucou-antigravity/Resources/rango.png"
        ]
        for path in fallbackPaths {
            if let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        return nil
    }
}
