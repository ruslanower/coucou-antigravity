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

    @State private var isLeftHovered = false
    @State private var isRightHovered = false

    // MARK: - 1. Idle Notch Wings (Окремі елегантні бічні капсули без перекриття центру і вікон)
    private var idleNotchPill: some View {
        HStack(spacing: 0) {
            // Ліве крило: Mochi маскот
            HStack(spacing: 0) {
                MochiFaceView(isBlinking: appState.isBlinking, mood: .happy)
                    .frame(width: 30, height: 17)
            }
            .frame(width: 52, height: 26)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.94))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.6), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 5, y: 1.5)
            )
            .scaleEffect(isLeftHovered ? 1.08 : 1.0)
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isLeftHovered = hovering
                }
            }
            .onTapGesture {
                SoundEffect.shared.play("greet")
            }

            // Повністю чистий простір по центру під фізичну камеру та шторку (240pt)
            Spacer(minLength: 240)

            // Праве крило: статус Antigravity
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.purple.opacity(0.9), radius: 3)

                Text("Antigravity")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.94))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 5, y: 1.5)
            )
            .scaleEffect(isRightHovered ? 1.05 : 1.0)
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isRightHovered = hovering
                }
            }
            .onTapGesture {
                AntigravityBridge.focusAntigravity()
            }
        }
        .padding(.top, 3)
        .frame(width: 440)
    }

    // MARK: - 2. Status Pill (У межах висоти меню)
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
        .frame(height: 26)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.purple.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 6, y: 1.5)
        )
        .padding(.top, 3)
    }

    // MARK: - 3. Question Card
    private func questionCard(q: QuestionModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(alignment: .center, spacing: 10) {
                MochiFaceView(isBlinking: false, mood: .excited)
                    .frame(width: 32, height: 24)

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
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.purple.opacity(0.3), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 12)
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
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.80, green: 0.64, blue: 0.98), Color(red: 0.60, green: 0.40, blue: 0.90)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            // Eyes
            HStack(spacing: 5) {
                eyeView
                eyeView
            }
            .offset(y: -1)

            // Blushing cheeks
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.pink.opacity(0.65))
                    .frame(width: 3, height: 3)
                Circle()
                    .fill(Color.pink.opacity(0.65))
                    .frame(width: 3, height: 3)
            }
            .offset(y: 2)
        }
    }

    @ViewBuilder
    private var eyeView: some View {
        if isBlinking {
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .frame(width: 3.5, height: 1.2)
        } else {
            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: 3, height: 3)
        }
    }
}

// MARK: - Notch Peeking Background Shape
struct NotchShape: Shape {
    var cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
