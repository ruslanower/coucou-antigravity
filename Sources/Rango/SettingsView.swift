import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Основні"
    case antigravity = "Antigravity"
    case notifications = "Сповіщення"
    case about = "Про програму"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .antigravity: return "wand.and.stars"
        case .notifications: return "bell.badge.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 6) {
                // App Branding Header
                HStack(spacing: 10) {
                    RangoAvatarView(size: 32)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rango")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("v1.0.0 для Antigravity")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 8)

                // Tab items
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 20)
                                .foregroundColor(selectedTab == tab ? .purple : .secondary)

                            Text(tab.rawValue)
                                .font(.system(size: 12.5, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .primary : .secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedTab == tab ? Color.purple.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(width: 175)
            .padding(8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content Area
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(appState: appState)
                case .antigravity:
                    AntigravitySettingsTab(appState: appState)
                case .notifications:
                    NotificationsSettingsTab(appState: appState)
                case .about:
                    AboutSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 580, height: 420)
    }
}

// MARK: - 1. General Settings Tab
struct GeneralSettingsTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Основні налаштування")
                    .font(.system(size: 16, weight: .bold))

                // Sound Section
                GroupBox(label: Label("Звуковий супровід", systemImage: "speaker.wave.2.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Увімкнути звуки Rango та сповіщень", isOn: $appState.soundEnabled)
                            .toggleStyle(.switch)

                        if appState.soundEnabled {
                            HStack {
                                Text("Гучність:")
                                    .font(.system(size: 12))
                                Slider(value: $appState.soundVolume, in: 0.0...1.0)
                                    .accentColor(.purple)
                                Button("Тест звуку") {
                                    SoundEffect.shared.play("greet")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(8)
                }

                // Auto-close section
                GroupBox(label: Label("Автозакриття карток", systemImage: "clock.fill")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Час автоматичного закриття картки, якщо ви не обрали варіант:")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)

                        Picker("Таймаут:", selection: $appState.autoCloseSeconds) {
                            Text("10 секунд").tag(10)
                            Text("30 секунд").tag(30)
                            Text("60 секунд").tag(60)
                            Text("120 секунд (Рекомендовано)").tag(120)
                            Text("Без обмежень").tag(0)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(8)
                }

                // Hover trigger
                GroupBox(label: Label("Поведінка чілки", systemImage: "hand.point.up.left.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Розгортати шторку при наведенні курсору миші", isOn: $appState.hoverExpandEnabled)
                            .toggleStyle(.switch)
                        Text("Коли ви підводите курсор до чілки, панель «Rango» автоматично опускається з елементами керування.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }

                // Auto-Update section
                GroupBox(label: Label("Оновлення Rango", systemImage: "arrow.triangle.2.circlepath")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Автоматично оновлювати Rango у фоні", isOn: $appState.autoUpdateEnabled)
                            .toggleStyle(.switch)
                        Text("При виході нових релізів на GitHub, Rango самостійно завантажить оновлення.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - 2. Antigravity Tab
struct AntigravitySettingsTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Інтеграція з Antigravity")
                    .font(.system(size: 16, weight: .bold))

                GroupBox(label: Label("Статус підключення", systemImage: "bolt.fill")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 9, height: 9)
                            Text("Активно та очікує подій")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                            Spacer()
                            Text("Порт: Unix Domain Socket")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Підтримує будь-які сесії та проекти Antigravity (IDE, CLI, сторонні машини).")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            Text("• Запитання автоматично дублюються в чілку та модальне вікно.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            Text("• Клік у чілці миттєво підтверджує вибір через емуляцію системних клавіш.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Spacer()
                            Button("Надіслати тестовий запит у чілку") {
                                appState.showQuestion(
                                    question: "Тест звʼязку: перевірка налаштувань «Rango»",
                                    options: ["(Рекомендовано) Все працює чудово!", "Варіант 2: Перевірка чілки"]
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.small)
                        }
                    }
                    .padding(8)
                }

                GroupBox(label: Label("Налаштування для друзів та інших пристроїв", systemImage: "network")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Щоб встановити «Rango» на іншому компʼютері чи поділитися з другом:")
                            .font(.system(size: 11.5))
                        Text("Виконайте команду в терміналі:")
                            .font(.system(size: 11, weight: .semibold))
                        HStack {
                            Text("curl -sSL https://raw.githubusercontent.com/ruslanower/rango/main/install.sh | bash")
                                .font(.system(size: 10, design: .monospaced))
                                .padding(6)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(4)
                            Button("Копіювати") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("curl -sSL https://raw.githubusercontent.com/ruslanower/rango/main/install.sh | bash", forType: .string)
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(8)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - 3. Notifications Tab (Social & Browser)
struct NotificationsSettingsTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Сповіщення соцмереж та браузера")
                    .font(.system(size: 16, weight: .bold))

                Text("«Rango» може відображати короткі інформаційні плашки у чілці при надходженні повідомлень з браузера чи додатків звʼязку:")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)

                GroupBox(label: Label("Канали сповіщень", systemImage: "bubble.left.and.bubble.right.fill")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $appState.notifyTelegram) {
                            HStack(spacing: 8) {
                                Text("✈️")
                                VStack(alignment: .leading) {
                                    Text("Telegram")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Text("Сповіщення про нові особисті повідомлення та згадки")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $appState.notifyWhatsApp) {
                            HStack(spacing: 8) {
                                Text("💬")
                                VStack(alignment: .leading) {
                                    Text("WhatsApp")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Text("Сповіщення з веб-версії або десктопного клієнта")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $appState.notifyViber) {
                            HStack(spacing: 8) {
                                Text("💜")
                                VStack(alignment: .leading) {
                                    Text("Viber")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Text("Повідомлення чатів")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $appState.notifyEmail) {
                            HStack(spacing: 8) {
                                Text("✉️")
                                VStack(alignment: .leading) {
                                    Text("Електронна пошта")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Text("Важливі вхідні листи (Apple Mail / Gmail)")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $appState.notifyBrowser) {
                            HStack(spacing: 8) {
                                Text("🌐")
                                VStack(alignment: .leading) {
                                    Text("Браузер (Chrome / Safari)")
                                        .font(.system(size: 12.5, weight: .medium))
                                    Text("Web Push сповіщення з активних вкладок браузера")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(8)
                }

                GroupBox(label: Label("Тестування сповіщень у чілці", systemImage: "sparkles")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Перевірте, як виглядають спливаючі повідомлення з телефону в чілці:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            Button(action: {
                                appState.showPhoneNotification(
                                    app: "Telegram",
                                    icon: "✈️",
                                    sender: "Олена",
                                    message: "Привіт! Зустріч підтверджено на 15:00."
                                )
                            }) {
                                HStack(spacing: 5) {
                                    Text("✈️")
                                    Text("Тест Telegram")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)

                            Button(action: {
                                appState.showPhoneNotification(
                                    app: "WhatsApp",
                                    icon: "💬",
                                    sender: "Андрій",
                                    message: "Файли проєкту надіслав, глянь коли буде час."
                                )
                            }) {
                                HStack(spacing: 5) {
                                    Text("💬")
                                    Text("Тест WhatsApp")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                        }
                    }
                    .padding(8)
                }

                GroupBox(label: Label("Як увімкнути сповіщення зі смартфона", systemImage: "iphone")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Чому сповіщення можуть не надходити:")
                            .font(.system(size: 11.5, weight: .semibold))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 6) {
                                Text("1.")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.purple)
                                Text("На iPhone: відкрийте **Параметри → Сповіщення → Дублювання iPhone** та увімкніть Telegram / WhatsApp.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            HStack(alignment: .top, spacing: 6) {
                                Text("2.")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.purple)
                                Text("На Mac (macOS Sequoia): відкрийте **Системні параметри → Сповіщення** і переконайтеся, що опція **«Дозволити сповіщення з iPhone»** увімкнена.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            HStack(alignment: .top, spacing: 6) {
                                Text("3.")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.purple)
                                Text("Для нативних клієнтів: встановіть Telegram / WhatsApp для Mac з App Store або офіційних сайтів.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - 4. About Tab
struct AboutSettingsTab: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @ObservedObject var appState = AppState.shared

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            RangoAvatarView(size: 64)
                .frame(width: 64, height: 64)

            VStack(spacing: 4) {
                Text("Rango")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Версія \(updateManager.currentVersion.version) (збірка \(updateManager.currentVersion.build))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Update Status Card
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if updateManager.isChecking || updateManager.isUpdating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else if updateManager.updateAvailable {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    Text(updateManager.statusMessage.isEmpty ? "У вас встановлено найновішу версію" : updateManager.statusMessage)
                        .font(.system(size: 11.5))
                        .foregroundColor(.primary)

                    Spacer()

                    if updateManager.updateAvailable {
                        Button(updateManager.isUpdating ? "Оновлення..." : "Оновити зараз") {
                            updateManager.performUpdate()
                        }
                        .disabled(updateManager.isUpdating)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                    } else {
                        Button("Перевірити") {
                            Task {
                                await updateManager.checkForUpdates(silent: false)
                            }
                        }
                        .disabled(updateManager.isChecking)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Toggle("Автоматичне оновлення у фоні", isOn: $appState.autoUpdateEnabled)
                    .font(.system(size: 11))
                    .toggleStyle(.checkbox)
            }
            .padding(10)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 30)

            Text("Нативний інтерактивний помічник чілки MacBook, що синхронізує запитання та генерує ідеї нових застосунків на основі твоїх проєктів у Google Antigravity.")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 6) {
                Text("Розробник: Руслан Барбуца")
                    .font(.system(size: 11.5, weight: .medium))
                Link("Відкрити репозиторій на GitHub", destination: URL(string: "https://github.com/ruslanower/rango")!)
                    .font(.system(size: 11))
            }

            Spacer()
        }
        .padding(20)
    }
}
