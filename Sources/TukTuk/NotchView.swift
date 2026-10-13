import SwiftUI

struct NotchView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        ZStack(alignment: .top) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 0)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.state {
        case .idle:
            idleNotchPill
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))

        case .hoverDrawer:
            hoverDrawerView
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

        case .status(let text):
            statusPill(text: text)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))

        case .question(let q):
            questionCard(q: q)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
    }

    // MARK: - 1. Idle Notch Pill (Акуратна компактна чілка з Mochi)
    @State private var isPillHovered = false

    private var idleNotchPill: some View {
        HStack(spacing: 8) {
            // Mochi з капелюхом чарівника
            MochiWithHatView(isBlinking: appState.isBlinking, mood: .happy, size: 22)
                .frame(width: 26, height: 24)

            // Індикатор активності Antigravity
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.purple.opacity(0.9), radius: 3)

                Text("Тук-тук")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.5), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 6, y: 2)
        )
        .padding(.top, 2)
        .scaleEffect(isPillHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isPillHovered = hovering
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

    @State private var currentIdea: StartupIdea? = nil

    // MARK: - 2. Hover Drawer View (Оригінальний інтерфейс Coucou з двома картками)
    private var hoverDrawerView: some View {
        VStack(spacing: 10) {
            // Top Bar: Іконки навігації зліва, кнопки налаштувань справа
            HStack(spacing: 12) {
                // Лівий блок: 🏠 💬 ➕
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
                            currentIdea = StartupIdeas.random()
                        }
                        SoundEffect.shared.play("pop")
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Отримати ідею для застосунку")
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
                    .help("Налаштування «Тук-тук»")

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
                // Картка 1: Mochi + Відкрити Antigravity
                Button(action: {
                    AntigravityBridge.focusAntigravity()
                    SoundEffect.shared.play("peek")
                    appState.close()
                }) {
                    HStack(spacing: 12) {
                        MochiWithHatView(isBlinking: appState.isBlinking, mood: .happy, size: 40)
                            .frame(width: 46, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 6, height: 6)
                                Text("Відкрити Antigravity")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Text("Швидкий запуск")
                                .font(.system(size: 10, weight: .medium))
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

                // Картка 2: Рандомайзер 333 ідей для застосунків
                if let idea = currentIdea {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(idea.category)
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.purple.opacity(0.2)))

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
                                    currentIdea = StartupIdeas.random()
                                }
                                SoundEffect.shared.play("blip")
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "dice.fill")
                                        .font(.system(size: 8))
                                    Text("Наступна ідея")
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
                                            colors: [Color.purple, Color.indigo],
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
                                    .stroke(Color.purple.opacity(0.45), lineWidth: 1)
                            )
                    )
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            currentIdea = StartupIdeas.random()
                        }
                        SoundEffect.shared.play("pop")
                    }) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.purple, Color.indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.yellow)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Отримати ідею")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("Для нового застосунку 🎲")
                                    .font(.system(size: 10, weight: .medium))
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
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 490, height: currentIdea != nil ? 144 : 118)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.purple.opacity(0.4), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.65), radius: 20, y: 10)
        .onHover { hovering in
            if hovering {
                appState.cancelScheduledCloseHover()
            } else {
                appState.scheduleCloseHoverDrawer()
            }
        }
    }

    // MARK: - 3. Status Pill
    private func statusPill(text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.purple)
                .frame(width: 6, height: 6)
                .shadow(color: Color.purple.opacity(0.9), radius: 4)

            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.purple.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 6, y: 1.5)
        )
        .padding(.top, 2)
    }

    // MARK: - 4. Question Card (Інтерактивна форма для запитань)
    private func questionCard(q: QuestionModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(alignment: .center, spacing: 10) {
                MochiWithHatView(isBlinking: false, mood: .excited, size: 30)
                    .frame(width: 34, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("ANTIGRAVITY")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color.purple, Color.indigo],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )

                        Text("Потрібна ваша дія")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Text(q.question)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(action: {
                    appState.close()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Options List
            VStack(spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { index, option in
                    OptionButton(index: index, label: option) {
                        appState.selectOption(at: index)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 490)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.purple.opacity(0.35), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 12)
    }
}

// MARK: - Option Button
struct OptionButton: View {
    let index: Int
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Number badge [1], [2], [3]
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovered ? .white : .purple.opacity(0.9))
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHovered ? Color.purple : Color.purple.opacity(0.2))
                    )

                Text(label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "arrow.return.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.25))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isHovered ? Color.purple.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Mochi Mascot with Purple Wizard Hat
struct MochiWithHatView: View {
    let isBlinking: Bool
    let mood: MochiFaceView.Mood
    var size: CGFloat = 36

    var body: some View {
        ZStack(alignment: .top) {
            // Squishy Mochi Body
            MochiFaceView(isBlinking: isBlinking, mood: mood)
                .frame(width: size, height: size * 0.72)
                .offset(y: size * 0.35)

            // Purple Wizard Hat with Star
            WizardHatView(size: size * 0.65)
                .offset(y: -size * 0.05)
        }
        .frame(width: size, height: size * 1.1)
    }
}

// MARK: - Mochi Mascot Face
struct MochiFaceView: View {
    let isBlinking: Bool
    let mood: Mood

    enum Mood {
        case happy
        case excited
    }

    var body: some View {
        ZStack {
            // Cute Lilac/Purple body
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.82, green: 0.68, blue: 0.98), Color(red: 0.62, green: 0.44, blue: 0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            // Eyes
            HStack(spacing: 6) {
                eyeView
                eyeView
            }
            .offset(y: -1)

            // Blushing cheeks
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.pink.opacity(0.65))
                    .frame(width: 3.5, height: 3.5)
                Circle()
                    .fill(Color.pink.opacity(0.65))
                    .frame(width: 3.5, height: 3.5)
            }
            .offset(y: 3)
        }
    }

    @ViewBuilder
    private var eyeView: some View {
        if isBlinking {
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .frame(width: 4, height: 1.2)
        } else {
            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: 3.5, height: 3.5)
        }
    }
}

// MARK: - Wizard Hat
struct WizardHatView: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            // Hat Cone
            HatConeShape()
                .fill(LinearGradient(
                    colors: [Color(red: 0.45, green: 0.22, blue: 0.75), Color(red: 0.32, green: 0.12, blue: 0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size, height: size)

            // Hat Brim
            Ellipse()
                .fill(Color(red: 0.30, green: 0.10, blue: 0.52))
                .frame(width: size * 1.35, height: size * 0.32)
                .offset(y: size * 0.42)

            // Golden Star on Hat
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.28))
                .foregroundColor(Color.yellow.opacity(0.95))
                .offset(x: -size * 0.08, y: size * 0.18)
        }
    }
}

struct HatConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX * 0.9, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.minY),
            control: CGPoint(x: rect.minX * 1.1, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}
