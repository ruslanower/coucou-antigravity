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

    // MARK: - 1. Idle Notch Pill
    private var idleNotchPill: some View {
        HStack(spacing: 8) {
            MochiFaceView(isBlinking: appState.isBlinking, mood: .happy)
                .frame(width: 32, height: 20)

            Text("Antigravity")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - 2. Status Pill
    private func statusPill(text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.purple)
                .frame(width: 8, height: 8)
                .shadow(color: Color.purple.opacity(0.8), radius: 4)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.purple.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 10, y: 4)
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
            // Little cute body/blob
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white, Color(white: 0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            // Face elements
            HStack(spacing: 6) {
                // Left eye
                eyeView
                // Right eye
                eyeView
            }

            // Blushing cheeks
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.pink.opacity(0.45))
                    .frame(width: 4, height: 4)
                Circle()
                    .fill(Color.pink.opacity(0.45))
                    .frame(width: 4, height: 4)
            }
            .offset(y: 3)
        }
    }

    @ViewBuilder
    private var eyeView: some View {
        if isBlinking {
            Rectangle()
                .fill(Color.black)
                .frame(width: 4, height: 1.5)
        } else {
            Circle()
                .fill(Color.black)
                .frame(width: 3.5, height: 3.5)
        }
    }
}
