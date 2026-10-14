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

    /// Зчитує всі виявлені проєкти Antigravity з директорії конфігурації
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

    /// Генерує стратегічну бізнес-ідею, аналізуючи загальний вектор усіх проєктів та мислення фаундера
    public func generateNextIdea() -> StartupIdea {
        let projects = getExistingProjects()
        let projectNames = projects.map { $0.name }

        // Пул стратегічних ідей за головними векторами розробника
        var candidates: [StartupIdea] = []

        // 1. Вектор: Smart FoodTech & Смарт-раціони (Сільпо)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "SmartBasket UA",
                category: "🥗 Smart FoodTech",
                description: "Автоматичний перерахунок рецептів із соцмереж у точний кошик продуктів супермаркету з вибором найвигідніших акцій.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("silpo") || $0.lowercased().contains("meal") }) ?? "silpo_smart_meal"
            ),
            StartupIdea(
                title: "MealPrep OS",
                category: "🥗 Смарт-харчування",
                description: "Конструктор раціону на 7 днів під точний калораж: генерує 1 список покупок і покроковий таймлайн готування за 2 години.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("silpo") || $0.lowercased().contains("meal") })
            ),
            StartupIdea(
                title: "Receipt2Menu",
                category: "🥗 AI Food Assistant",
                description: "Скануєш чек із супермаркету, а ШІ миттєво складає меню страв на 3 дні із куплених продуктів, щоб нічого не зіпсувалося.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("silpo") || $0.lowercased().contains("meal") })
            ),
            StartupIdea(
                title: "CleanEat Scanner",
                category: "🥗 Health & Nutrition",
                description: "Миттєве виявлення прихованого цукру, трансжирів та шкідливих добавок на етикетках українських продуктів через камеру.",
                basedOnProject: "silpo_smart_meal-3"
            )
        ])

        // 2. Вектор: Fitness & Coach OS (Для тренерів)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "CoachDesk Mobile",
                category: "🏋️‍♂️ Fitness & Coach OS",
                description: "Мобільний кабінет тренера: ведення підопічних, онлайн-оплати підписок у Telegram/Monobank та автонагадування про тренування.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("тренер") }) ?? "Для тренерів"
            ),
            StartupIdea(
                title: "FormVision AI",
                category: "🏋️‍♂️ AI Спортивний аналіз",
                description: "Аналізатор техніки виконання присідань і тяги через камеру смартфона з візуалізацією кутів суглобів та голосовими підказками.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("тренер") })
            ),
            StartupIdea(
                title: "ClientDopamine",
                category: "🏋️‍♂️ Гейміфікація тренувань",
                description: "Трекер звичок для підопічних: нарахування балів за регулярність, челенджі прогресу та щотижневі фотозвіти «до/після».",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("тренер") })
            ),
            StartupIdea(
                title: "NutriSync Coach",
                category: "🏋️‍♂️ Тренери + Нутриціологія",
                description: "Клієнт фотографує тарілку з їжею, ШІ рахує калорії, а тренер бачить зведений звіт за тиждень в один дотик.",
                basedOnProject: "Для тренерів"
            )
        ])

        // 3. Вектор: AI Video Engine & Контент-фабрика (Video VanzaLabs, Відео мотивація)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "HookMaster AI",
                category: "🎬 AI Video & Медіа",
                description: "Генератор перших 3-секундних вірусних хуків, заголовків та перших кадрів для Reels/Shorts на основі трендів TikTok.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("video") || $0.lowercased().contains("відео") }) ?? "Video VanzaLabs"
            ),
            StartupIdea(
                title: "AutoShorts Lab",
                category: "🎬 Автоматизація відео",
                description: "Завантажуєш довге відео чи підкаст — система знаходить 5 найгарячіших моментів, нарізає вертикально і додає караоке-субтитри.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("video") || $0.lowercased().contains("відео") })
            ),
            StartupIdea(
                title: "VanzaVoice Clips",
                category: "🎬 Мотиваційний контент",
                description: "ШІ-генератор коротких мотиваційних відео: реалістичний голос диктора, кінематографічний B-roll та динамічні ефекти.",
                basedOnProject: "відео мотивація"
            ),
            StartupIdea(
                title: "ViralSound Radar",
                category: "🎬 SMM & Віральність",
                description: "Щоденний трекер аудіодоріжок в Instagram і TikTok, які стрімко набирають популярність, з ідеями для зйомок у вашій ніші.",
                basedOnProject: "Video VanzaLabs"
            )
        ])

        // 4. Вектор: 100% Вийде | Дисципліна, Цілі та Результат (100%вийде, Goal Tracker)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "PactHero UA",
                category: "🚀 100% Вийде | Дисципліна",
                description: "Сервіс залізних зобов'язань: ставиш мету, вносиш заставу, і якщо завдання не виконано до вечора — кошти йдуть на благодійність.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("100%") || $0.lowercased().contains("goal") }) ?? "100%вийде"
            ),
            StartupIdea(
                title: "OneTask Daily",
                category: "🚀 Фокус та Продуктивність",
                description: "Мінімалістичний трекер, який забороняє братися за другорядні справи, поки 1 головна задача дня не виконана на 100%.",
                basedOnProject: "100%вийде"
            ),
            StartupIdea(
                title: "Accountability Bot",
                category: "🚀 ШІ-напарник з цілей",
                description: "Бот у Telegram, який щоранку фіксує ваш пріоритет, а ввечері жорстко розбирає підсумки дня без самообману та відмовок.",
                basedOnProject: "goal_tracker (19)"
            ),
            StartupIdea(
                title: "FounderStreak",
                category: "🚀 Стартап-щоденник",
                description: "Щоденний журнал запуску стартапу: фіксація 1 продажу чи корисного релізу щодня із підрахунком безперервної серії днів.",
                basedOnProject: "100%вийде"
            )
        ])

        // 5. Вектор: Vanza Business & Автоматизація Документів (VANZA ДОКУМЕНТИ, FormGrid)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "DiiaDoc Sign",
                category: "⚡️ Vanza Legal Tech",
                description: "Мобільний конструктор і підписання договорів оренди, послуг та NDA через Дія.Підпис за 60 секунд без друку на папері.",
                basedOnProject: projectNames.first(where: { $0.lowercased().contains("документ") || $0.lowercased().contains("vanza") }) ?? "VANZA ДОКУМЕНТИ"
            ),
            StartupIdea(
                title: "FOP Invoice Bot",
                category: "⚡️ Бізнес-автоматизація",
                description: "Миттєве виставлення рахунків та актів виконаних робіт для ФОП 3-ї групи прямо в діалозі Telegram із автоперевіркою IBAN.",
                basedOnProject: "VANZA ДОКУМЕНТИ"
            ),
            StartupIdea(
                title: "ContractAudit AI",
                category: "⚡️ Юридичний ШІ-аудит",
                description: "Завантажте PDF-договір — ШІ виявить приховані пені, штрафи та невигідні пункти за 15 секунд із поясненням людською мовою.",
                basedOnProject: "VANZA ДОКУМЕНТИ"
            ),
            StartupIdea(
                title: "FormGrid Intake",
                category: "⚡️ FormGrid No-Code",
                description: "Розумний збирач заявок і клієнтських брифів: дані з форм автоматично структурують базу клієнтів без сторонніх CRM.",
                basedOnProject: "FormGrid"
            )
        ])

        // 6. Вектор: Ambient Mac & Системні ШІ-інструменти (Rango, Антігравіті)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "NotchNotes AI",
                category: "💻 Ambient Mac AI",
                description: "Швидкі нотатки прямо в чілці Mac: наведення на чілку відкриває поле швидкої фіксації думок із автосинхронізацією в Notion.",
                basedOnProject: "Антігравіті"
            ),
            StartupIdea(
                title: "FocusIsland Mac",
                category: "💻 Dynamic Island Utility",
                description: "Візуалізація таймера Pomodoro та поточної робочої задачі прямо у фізичній чілці екрана MacBook без відволікання від коду.",
                basedOnProject: "Антігравіті"
            ),
            StartupIdea(
                title: "VoiceClip Mac",
                category: "💻 Швидкі ШІ-нотатки",
                description: "Затискаєш гарячу клавішу, надиктовуєш думку — ШІ очищає слова-паразити, структурує по пунктах і копіює готовий текст у буфер.",
                basedOnProject: "Антігравіті"
            ),
            StartupIdea(
                title: "DevClean Auto",
                category: "💻 macOS оптимізація",
                description: "Фоновий клінер для розробників: автоматично знаходить гігабайти застарілих кешів Xcode, DerivedData та старих node_modules.",
                basedOnProject: "Антігравіті"
            )
        ])

        // 7. Вектор: Мікро-SaaS & Медіа-інструменти (Фотоконвектор, WorkHub)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "MarketPic AI",
                category: "💡 E-Commerce Мікро-SaaS",
                description: "Пакетне перетворення фото товарів зі смартфона у студійні картки для Rozetka та Prom з білим фоном і правильними тінями.",
                basedOnProject: "фотоконвектор"
            ),
            StartupIdea(
                title: "WebP SpeedBatch",
                category: "💡 Медіа-оптимізація",
                description: "Миттєве пакетне стиснення зображень у надсучасний формат WebP/AVIF без втрати якості для прискорення завантаження сайтів.",
                basedOnProject: "фотоконвектор"
            ),
            StartupIdea(
                title: "WorkHub FocusPod",
                category: "💡 WorkHub & Простори",
                description: "Мапа вільних робочих місць у коворкінгах і тихих кав'ярнях міста зі стабільним Starlink і живленням під час відключень.",
                basedOnProject: "WorkHub"
            )
        ])

        // 8. Вектор: GovTech & Смарт-громада (ОДА)
        candidates.append(contentsOf: [
            StartupIdea(
                title: "CityVoice ОДА",
                category: "🏛 GovTech & Смарт-сервіси",
                description: "Мобільний сервіс звернень громадян із геоприв'язкою фото, автоматичним визначенням служби та публічним трекінгом виконання робіт.",
                basedOnProject: "ОДА"
            ),
            StartupIdea(
                title: "LocalSafety Map",
                category: "🏛 Міська безпека",
                description: "Інтерактивна мапа пунктів підтримки, укриттів та медичних чергових служб регіону з оновленням статусу в реальному часі.",
                basedOnProject: "ОДА"
            )
        ])

        // 9. Вектор: Проривні синергії між ключовими напрямками
        candidates.append(contentsOf: [
            StartupIdea(
                title: "CoachMeal Sync",
                category: "🔥 Синергія: Тренери + Сільпо",
                description: "Тренер формує план харчування у своїй системі, а клієнт в один клік замовляє всі потрібні продукти у супермаркеті з доставкою.",
                basedOnProject: "Для тренерів",
                synergyProjects: ["Для тренерів", "silpo_smart_meal-3"]
            ),
            StartupIdea(
                title: "ShortsMotivation AI",
                category: "🔥 Синергія: Відео + Мотивація",
                description: "Автоматична щоденна генерація мотивуючих Reels для соцмереж: ШІ компонує цитату, динамічний відеоряд, субтитри та саундтрек.",
                basedOnProject: "відео мотивація",
                synergyProjects: ["відео мотивація", "Video VanzaLabs"]
            ),
            StartupIdea(
                title: "GoalPact Docs",
                category: "🔥 Синергія: Цілі + Документи",
                description: "Юридично оформлений соціальний договір партнерів про запуск проєкту в строк із публічним трекінгом та дисциплінарними заставами.",
                basedOnProject: "100%вийде",
                synergyProjects: ["100%вийде", "VANZA ДОКУМЕНТИ"]
            ),
            StartupIdea(
                title: "CoachVideo Clips",
                category: "🔥 Синергія: Тренери + Відео",
                description: "ШІ-конвертація рутинних відео тренувань у вірусні демонстраційні Reels для залучення нових платних клієнтів тренеру в Instagram.",
                basedOnProject: "Для тренерів",
                synergyProjects: ["Для тренерів", "Video VanzaLabs"]
            )
        ])

        // Перемішуємо і шукаємо ідею, яка ще не була нещодавно показана
        let shuffled = candidates.shuffled()
        for candidate in shuffled {
            if registerIdea(candidate) {
                return candidate
            }
        }

        // Якщо всі нещодавно показувалися — очищаємо частину історії і беремо першу випадкову
        recentIdeaTitles.removeAll()
        let fallback = shuffled.first!
        _ = registerIdea(fallback)
        return fallback
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
}
