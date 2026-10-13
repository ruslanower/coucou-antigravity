import Foundation

public struct StartupIdea: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let category: String
    public let description: String
    public let basedOnProject: String?
    public let synergyProjects: [String]?

    public init(
        id: UUID = UUID(),
        title: String,
        category: String,
        description: String,
        basedOnProject: String? = nil,
        synergyProjects: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.description = description
        self.basedOnProject = basedOnProject
        self.synergyProjects = synergyProjects
    }
}

public struct AntigravityProject: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let folderUri: String?
}

public final class ProjectIdeaGenerator {
    public static let shared = ProjectIdeaGenerator()

    private var recentIdeaTitles: Set<String> = []
    private let maxRecentHistory = 40

    public init() {}

    /// Зчитує всі активні проєкти Antigravity з директорії конфігурації
    public func getExistingProjects() -> [AntigravityProject] {
        let projectsDir = NSString(string: "~/.gemini/config/projects").expandingTildeInPath
        let fm = FileManager.default
        var projects: [AntigravityProject] = []

        guard let files = try? fm.contentsOfDirectory(atPath: projectsDir) else {
            return []
        }

        for file in files where file.hasSuffix(".json") && file != "outside-of-project.json" {
            let path = (projectsDir as NSString).appendingPathComponent(file)
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["name"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            var folderUri: String? = nil
            if let workspaces = json["workspaces"] as? [[String: Any]],
               let first = workspaces.first,
               let uri = first["folderUri"] as? String {
                folderUri = uri
            }

            let id = file.replacingOccurrences(of: ".json", with: "")
            projects.append(AntigravityProject(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), folderUri: folderUri))
        }

        return projects.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
    }

    /// Генерує нову ідею: на основі одного з існуючих проєктів, синергії двох проєктів або випадкову
    public func generateNextIdea() -> StartupIdea {
        let projects = getExistingProjects()

        // Якщо є існуючі проєкти — у 85% випадків генеруємо на основі проєктів або їх синергії
        if !projects.isEmpty {
            let modeRoll = Double.random(in: 0...1)

            if modeRoll < 0.55 {
                // Варіант 1: Ідея, заточена під конкретний проєкт
                if let chosen = projects.randomElement() {
                    let idea = generateIdeaForProject(chosen)
                    if registerIdea(idea) { return idea }
                }
            } else if modeRoll < 0.85 && projects.count >= 2 {
                // Варіант 2: Синергія двох проєктів
                let shuffled = projects.shuffled()
                let p1 = shuffled[0]
                let p2 = shuffled[1]
                let idea = generateSynergyIdea(p1: p1, p2: p2)
                if registerIdea(idea) { return idea }
            }
        }

        // Варіант 3: Рандомна конкурентоспроможна бізнес-ідея
        let standalone = generateStandaloneIdea()
        _ = registerIdea(standalone)
        return standalone
    }

    private func registerIdea(_ idea: StartupIdea) -> Bool {
        if recentIdeaTitles.contains(idea.title) {
            return false
        }
        recentIdeaTitles.insert(idea.title)
        if recentIdeaTitles.count > maxRecentHistory {
            recentIdeaTitles.removeFirst()
        }
        return true
    }

    // MARK: - Генератор під конкретний проєкт

    private func generateIdeaForProject(_ project: AntigravityProject) -> StartupIdea {
        let nameLower = project.name.lowercased()

        // 1. Фітнес / Тренери
        if nameLower.contains("тренер") || nameLower.contains("fit") || nameLower.contains("gym") || nameLower.contains("спорт") {
            let pool: [(String, String, String)] = [
                ("TrainersPay UA", "🎯 На основі: \(project.name)", "Швидкий мобільний білінг та підписки на тренування через Apple Pay та Monobank прямо в Telegram/iOS."),
                ("FormVision AI", "🎯 На основі: \(project.name)", "AI-аналізатор техніки виконання присідань і тяги через камеру iPhone з миттєвими голосовими підказками."),
                ("CoachClient CRM", "🎯 На основі: \(project.name)", "Мобільний щоденник вимірів, ваги та фото «до/після» підопічних із автоматичними нагадуваннями про тренування."),
                ("WorkoutVoice AI", "🎯 На основі: \(project.name)", "Голосовий асистент, який записує робочу вагу та повторення під час тренування без необхідності торкатися екрана."),
                ("CoachStore", "🎯 На основі: \(project.name)", "Мікро-маркетплейс для продажу авторських гайдів, планів харчування та консультацій тренера в 1 клік.")
            ]
            let pick = pool.randomElement()!
            return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
        }

        // 2. YouTube / Відео автоматизація / Мотивація
        if nameLower.contains("ютюб") || nameLower.contains("youtube") || nameLower.contains("відео") || nameLower.contains("video") || nameLower.contains("мотивац") {
            let pool: [(String, String, String)] = [
                ("ShortsHook AI", "🎯 На основі: \(project.name)", "Автоматичний генератор перших 3-секундних вірусних хуків та заголовків для YouTube Shorts та Reels."),
                ("AutoB-Roll Studio", "🎯 На основі: \(project.name)", "AI-сервіс, який автоматично нарізає динамічний B-Roll відеоряд під аудіодоріжку голосу автора."),
                ("VoiceMotivator Daily", "🎯 На основі: \(project.name)", "Щоденний персональний віджет із 30-секундними аудіо-мотиваціями та цитатами під настрій користувача."),
                ("ClipForge Pro", "🎯 На основі: \(project.name)", "Конвертація довгих YouTube-інтерв'ю у 5 вірусних Shorts із анімованими караоке-субтитрами та авто-звуками."),
                ("ViralSound Tracker", "🎯 На основі: \(project.name)", "Моніторинг трендових аудіо доріжок та алгоритмічний підбір музики під нішу каналу для максимізації охоплень.")
            ]
            let pick = pool.randomElement()!
            return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
        }

        // 3. Документи / Форми / VANZA / FormGrid
        if nameLower.contains("документ") || nameLower.contains("vanza") || nameLower.contains("form") || nameLower.contains("grid") || nameLower.contains("договір") {
            let pool: [(String, String, String)] = [
                ("DocSign Mobile UA", "🎯 На основі: \(project.name)", "Мобільний підпис та погодження договорів оренди і послуг через Дія.Підпис у 2 дотики з iPhone."),
                ("InvoiceFlow Bot", "🎯 На основі: \(project.name)", "Автоматичне створення рахунків та актів виконаних робіт для ФОП 3-ї групи прямо з діалогу месенджера."),
                ("ContractRisk AI", "🎯 На основі: \(project.name)", "AI-сканер юридичних ризиків у PDF: знаходить приховані пені, штрафи та невигідні умови за 10 секунд."),
                ("VoiceForms Pro", "🎯 На основі: \(project.name)", "Створення складних бізнес-форм та опитувань голосом з автоматичним експортом у таблиці та CRM."),
                ("ActFast UA", "🎯 На основі: \(project.name)", "Шаблонізатор актів надання послуг із автозаповненням реквізитів за ЄДРПОУ компанії.")
            ]
            let pick = pool.randomElement()!
            return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
        }

        // 4. Їжа / Сільпо / Харчування
        if nameLower.contains("сільпо") || nameLower.contains("silpo") || nameLower.contains("meal") || nameLower.contains("їж") || nameLower.contains("рецепт") {
            let pool: [(String, String, String)] = [
                ("SmartCart Silpo", "🎯 На основі: \(project.name)", "Автоматичний підбір інгредієнтів для меню на тиждень і складання кошика доставки в Сільпо за 1 клік."),
                ("FridgeZero Waste", "🎯 На основі: \(project.name)", "Сканер чека супермаркету, який відстежує терміни придатності продуктів і пропонує рецепти із залишків."),
                ("CalorieScan UA", "🎯 На основі: \(project.name)", "Мобільний сканер штрих-кодів українських продуктів з точним підрахунком білків, жирів та калорій."),
                ("FamilyBudget Menu", "🎯 На основі: \(project.name)", "Генератор збалансованого сімейного раціону під заданий тижневий бюджет із перевіркою акційних цін."),
                ("MacroPrep AI", "🎯 На основі: \(project.name)", "Персональний конструктор ланчбоксів на тиждень із списком закупок та покроковим таймером приготування.")
            ]
            let pick = pool.randomElement()!
            return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
        }

        // 5. Цілі / Трекінг / Стартапи / 100%вийде
        if nameLower.contains("goal") || nameLower.contains("100%") || nameLower.contains("track") || nameLower.contains("вийде") || nameLower.contains("стартап") {
            let pool: [(String, String, String)] = [
                ("StreakPact Mobile", "🎯 На основі: \(project.name)", "Трекер звичок із фінансовим заставою та дружніми челенджами: виконай мету або сплати штраф другу."),
                ("MVP Launchpad 14", "🎯 На основі: \(project.name)", "14-денний покроковий трекер валідації стартапу: від ідеї до перших 3 платних користувачів."),
                ("AccountabilityBuddy AI", "🎯 На основі: \(project.name)", "AI-партнер у Telegram, який щовечора питає про головне завдання дня і не дає прокрастинувати."),
                ("PitchRoast AI", "🎯 На основі: \(project.name)", "Симулятор інвестиційного пітчу: тренування відповідей на жорсткі запитання ангельських інвесторів."),
                ("HabitIsland Dynamic", "🎯 На основі: \(project.name)", "Гейміфікований трекер мікро-цілей у Dynamic Island та віджетах macOS і iOS.")
            ]
            let pick = pool.randomElement()!
            return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
        }

        // 6. Робота / WorkHub / Коворкінг
        if nameLower.contains("work") || nameLower.contains("hub") || nameLower.contains("ворк") || nameLower.contains("офіс") {
            let pool: [(String, String, String)] = [
                ("DeskShare Instant", "🎯 На основі: \(project.name)", "Миттєве бронювання вільного робочого місця або skype-кімнати в коворкінгах міста без дзвінків."),
                ("TeamStandup Lite", "🎯 На основі: \(project.name)", "Асинхронний мобільний щоденний стендап для віддалених команд із AI-підсумками для менеджера."),
                ("FocusPod UA", "🎯 На основі: \(project.name)", "Мапа безшумних кав'ярень та коворкінгів зі стабільним Starlink і живленням під час відключень."),
                ("CoWorkCommunity", "🎯 На основі: \(project.name)", "Нетворкінг-додаток для резидентів спільних офісів: пошук розробників, дизайнерів та партнерів.")
            ]
            let pick = pool.randomElement()!
            return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
        }

        // 7. Фото / Конвертер
        if nameLower.contains("фото") || nameLower.contains("photo") || nameLower.contains("конвект") || nameLower.contains("конверт") {
            let pool: [(String, String, String)] = [
                ("BatchWebP Studio", "🎯 На основі: \(project.name)", "Пакетне стиснення зображень до WebP/AVIF без втрати якості для прискорення веб-сайтів."),
                ("ProductPic AI", "🎯 На основі: \(project.name)", "Видалення фону з фото товарів і підстановка студійного світла та інтер'єру для Rozetka та Prom."),
                ("SmartPDF Shrink", "🎯 На основі: \(project.name)", "Оптимізація сканів документів з 50 МБ до 2 МБ для швидкого надсилання електронною поштою."),
                ("WatermarkBatch", "🎯 На основі: \(project.name)", "Швидке брендування та накладання водяних знаків на серію фото для соцмереж та каталогів.")
            ]
            let pick = pool.randomElement()!
            return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
        }

        // 8. Загальний шаблон під будь-який інший виявлений проєкт
        let generalPool: [(String, String, String)] = [
            ("\(project.name) Mobile Companion", "🎯 На основі: \(project.name)", "Мобільний клієнт швидкого доступу до ключових операцій та сповіщень проєкту «\(project.name)»."),
            ("\(project.name) AI Copilot", "🎯 На основі: \(project.name)", "Автоматизований AI-помічник для прискорення рутинних завдань у системі «\(project.name)»."),
            ("\(project.name) Analytics Dashboard", "🎯 На основі: \(project.name)", "Зручний віджет аналітики та ключових метрик успішності для проєкту «\(project.name)»."),
            ("\(project.name) Telegram Bot", "🎯 На основі: \(project.name)", "Швидкий чат-бот для взаємодії з клієнтами та збору заявок для «\(project.name)» прямо з смартфона.")
        ]
        let pick = generalPool.randomElement()!
        return StartupIdea(title: pick.0, category: pick.1, description: pick.2, basedOnProject: project.name)
    }

    // MARK: - Синергія двох проєктів

    private func generateSynergyIdea(p1: AntigravityProject, p2: AntigravityProject) -> StartupIdea {
        let n1 = p1.name
        let n2 = p2.name

        // Комбінація тренери + їжа
        if (n1.lowercased().contains("тренер") || n2.lowercased().contains("тренер")) &&
           (n1.lowercased().contains("сільпо") || n2.lowercased().contains("сільпо") || n1.lowercased().contains("meal") || n2.lowercased().contains("meal")) {
            return StartupIdea(
                title: "CoachMeal Sync",
                category: "⚡️ Синергія: Тренери + Їжа",
                description: "Тренер складає персональний раціон у додатку, а підопічний замовляє всі потрібні продукти в супермаркеті у 1 клік.",
                basedOnProject: n1,
                synergyProjects: [n1, n2]
            )
        }

        // Комбінація YouTube + Мотивація
        if (n1.lowercased().contains("ютюб") || n2.lowercased().contains("ютюб")) &&
           (n1.lowercased().contains("мотивац") || n2.lowercased().contains("мотивац")) {
            return StartupIdea(
                title: "AutoMotiv Channel",
                category: "⚡️ Синергія: YouTube + Мотивація",
                description: "Повністю автономна фабрика контенту: AI обирає тему, пише сценарій, генерує голос і публікує 3 мотиваційні Shorts щодня.",
                basedOnProject: n1,
                synergyProjects: [n1, n2]
            )
        }

        // Комбінація Документи + WorkHub
        if (n1.lowercased().contains("документ") || n2.lowercased().contains("документ") || n1.lowercased().contains("vanza") || n2.lowercased().contains("vanza")) &&
           (n1.lowercased().contains("work") || n2.lowercased().contains("work") || n1.lowercased().contains("hub") || n2.lowercased().contains("hub")) {
            return StartupIdea(
                title: "CoworkContract Pro",
                category: "⚡️ Синергія: WorkHub + Документи",
                description: "Автоматичні договори оренди робочих місць, NDA та акти для коворкінгів із швидким підписом через смартфон.",
                basedOnProject: n1,
                synergyProjects: [n1, n2]
            )
        }

        // Комбінація Цілі + 100%вийде
        if (n1.lowercased().contains("goal") || n2.lowercased().contains("goal")) &&
           (n1.lowercased().contains("100%") || n2.lowercased().contains("100%")) {
            return StartupIdea(
                title: "FounderStreak",
                category: "⚡️ Синергія: Цілі + Стартап",
                description: "Щоденний фокус-трекер для фаундерів: не засинай, поки не зробиш 1 дію для залучення клієнтів або покращення продукту.",
                basedOnProject: n1,
                synergyProjects: [n1, n2]
            )
        }

        // Універсальна синергія двох довільних проєктів
        let title = "\(cleanShortName(n1))+\(cleanShortName(n2)) Gateway"
        return StartupIdea(
            title: title,
            category: "⚡️ Синергія проєктів",
            description: "Єдиний інтеграційний мікро-сервіс, що об'єднує робочі потоки між «\(n1)» та «\(n2)» для автоматизації бізнес-рутини.",
            basedOnProject: n1,
            synergyProjects: [n1, n2]
        )
    }

    private func cleanShortName(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        return cleaned.prefix(8).capitalized
    }

    // MARK: - Рандомні самостійні ідеї стартапів

    private func generateStandaloneIdea() -> StartupIdea {
        let pool: [StartupIdea] = [
            StartupIdea(
                title: "SubTrack UA",
                category: "💡 FinTech • Мобільний додаток",
                description: "Сканер виписок банків (Monobank, Приват) для виявлення та скасування забутих платних підписок та сервісів."
            ),
            StartupIdea(
                title: "QuickPitch AI",
                category: "💡 B2B SaaS • ШІ для продажів",
                description: "Генератор персоналізованих комерційних пропозицій та холодних листів у LinkedIn під профіль конкретного клієнта."
            ),
            StartupIdea(
                title: "NeuroSleep Assistant",
                category: "💡 HealthTech • Мобільний додаток",
                description: "Розумний будильник із адаптивними звуковими хвилями та аналізом фаз сну для легкого ранкового підйому."
            ),
            StartupIdea(
                title: "RentalInspector UA",
                category: "💡 RealEstate • Сервіс для орендарів",
                description: "Мобільний чеклист прийому квартири в оренду з фіксацією дефектів фотографіями та формуванням юридичного акта."
            ),
            StartupIdea(
                title: "PetHealth Pass",
                category: "💡 PetCare • Мобільний додаток",
                description: "Електронна веткнижка з нагадуваннями про вакцинацію, пошуком цілодобових чергових клінік та викликом ветеринара."
            ),
            StartupIdea(
                title: "LocalBarter UA",
                category: "💡 Marketplace • Екологічний обмін",
                description: "Місцева платформа обміну якісними речами та книгами поруч у радіусі 1-2 км без використання грошей."
            ),
            StartupIdea(
                title: "StudyFlash AI",
                category: "💡 EdTech • Мобільне навчання",
                description: "Миттєве створення інтерактивних карток із конспектів та PDF-лекцій для швидкої підготовки до іспитів за методом Anki."
            ),
            StartupIdea(
                title: "GreenPlant Doctor",
                category: "💡 AI Lifestyle • Сканер рослин",
                description: "Діагностика хвороб кімнатних рослин за фотографією листка з персональним графіком поливу та добрив."
            )
        ]

        return pool.randomElement()!
    }
}
