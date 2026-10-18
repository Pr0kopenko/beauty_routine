import Foundation

// Данные приложения. Формат совместим с JSON-копией PWA (web/logic.js),
// поэтому копию из веб-версии можно импортировать как есть.

struct AppState: Codable, Equatable {
    static let schemaVersion = 2

    var version: Int = AppState.schemaVersion
    var onboarded: Bool = false
    var items: [Item] = []
    var entries: [Entry] = []
    var rules: [String: Bool] = Dictionary(uniqueKeysWithValues: Catalog.rules.map { ($0.id, $0.defaultOn) })
    var reminders: Reminders = Reminders()
    var lastBackupAt: String? = nil
    var diary: [String: DiaryDay] = [:]
    var settings: Settings = Settings()
    var startedAt: String? = nil

    init() {}

    enum CodingKeys: String, CodingKey { case version, onboarded, items, entries, rules, reminders, lastBackupAt, diary, settings, startedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? true
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        entries = try c.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        var r = Dictionary(uniqueKeysWithValues: Catalog.rules.map { ($0.id, $0.defaultOn) })
        for (k, v) in try c.decodeIfPresent([String: Bool].self, forKey: .rules) ?? [:] { r[k] = v }
        rules = r
        reminders = try c.decodeIfPresent(Reminders.self, forKey: .reminders) ?? Reminders()
        lastBackupAt = try c.decodeIfPresent(String.self, forKey: .lastBackupAt)
        diary = try c.decodeIfPresent([String: DiaryDay].self, forKey: .diary) ?? [:]
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
    }

    func ruleOn(_ id: String) -> Bool { rules[id] ?? true }
    func item(_ id: String) -> Item? { items.first { $0.id == id } }
}

struct Item: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var brand: String = ""
    var type: String = "other"
    var actives: [String] = []
    var retinoidForm: String? = nil
    var strength: String = ""
    var composition: String = ""
    /// Миниатюра: имя файла в папке фото (нативно) или data URL (импорт из PWA).
    var thumb: String? = nil
    var note: String = ""
    var block: String = "optional"
    var schedule: Schedule = Schedule()
    var archived: Bool = false
    var dose: String = ""
    var createdAt: String? = nil
    /// Схема введения из надёжного источника: производитель, вкладыш, врач, вручную. nil — общее правило.
    var introPlan: IntroPlan? = nil

    init(id: String, name: String, actives: [String] = [], block: String = "optional", schedule: Schedule = Schedule(), type: String = "other", retinoidForm: String? = nil) {
        self.id = id; self.name = name; self.actives = actives; self.block = block; self.schedule = schedule; self.type = type; self.retinoidForm = retinoidForm
    }

    enum CodingKeys: String, CodingKey { case id, name, brand, type, actives, retinoidForm, strength, composition, thumb, note, block, schedule, archived, dose, createdAt, introPlan }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Без названия"
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        actives = try c.decodeIfPresent([String].self, forKey: .actives) ?? []
        retinoidForm = try c.decodeIfPresent(String.self, forKey: .retinoidForm)
        strength = try c.decodeIfPresent(String.self, forKey: .strength) ?? ""
        composition = try c.decodeIfPresent(String.self, forKey: .composition) ?? ""
        thumb = try c.decodeIfPresent(String.self, forKey: .thumb)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        block = try c.decodeIfPresent(String.self, forKey: .block) ?? "optional"
        schedule = try c.decodeIfPresent(Schedule.self, forKey: .schedule) ?? Schedule()
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        dose = try c.decodeIfPresent(String.self, forKey: .dose) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        introPlan = try? c.decodeIfPresent(IntroPlan.self, forKey: .introPlan)
    }

    var isRetinoid: Bool { actives.contains("retinoid") }
    var isIntervalRetinoid: Bool { isRetinoid && schedule.type == "interval" }
    var hasAcid: Bool { actives.contains { Catalog.acidGroup.contains($0) } }
    var isExfoliating: Bool { hasAcid || actives.contains("exfoliant") || type == "peel" }
    var isOxidizableRetinoid: Bool { isRetinoid && retinoidForm != "adapalene" }
    var form: RetinoidForm { Catalog.retinoidForms[retinoidForm ?? "retinol"] ?? Catalog.retinoidForms["retinol"]! }
}

/// Схема введения средства с источником.
struct IntroPlan: Codable, Equatable, Hashable {
    /// manufacturer · leaflet · doctor · cosmetologist · user · ai
    var source: String = "user"
    /// Стартовая частота (id из Catalog.frequencies).
    var start: String = "2w"
    /// Через сколько недель без раздражения повышать; nil — не повышать.
    var stepUpWeeks: Int? = 2
    var max: String = "daily"
    /// morning · evening · any; nil — не указано.
    var timeOfDay: String? = nil
    var note: String = ""
    var quote: String? = nil
    var url: String? = nil
    var addedAt: String? = nil

    static let sourceNames: [(id: String, name: String)] = [
        ("leaflet", "Вкладыш или упаковка"), ("doctor", "Врач"), ("cosmetologist", "Косметолог"),
        ("manufacturer", "Сайт производителя"), ("user", "Сама"), ("ai", "Нашёл ИИ"),
    ]
    var sourceName: String { IntroPlan.sourceNames.first { $0.id == source }?.name ?? source }
    /// Лестница частот этой схемы.
    var ladder: [String] {
        let all = Catalog.allFrequencies
        guard let a = all.firstIndex(of: start), let b = all.firstIndex(of: max), a <= b else { return [start] }
        return Array(all[a...b])
    }
}

struct Schedule: Codable, Equatable, Hashable {
    /// daily · interval · asneeded
    var type: String = "daily"
    var freq: String? = nil
    var since: String? = nil
    var snoozeUntil: String? = nil
}

struct Entry: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var itemId: String
    var day: String
    /// morning · evening
    var slot: String
    var at: String = ""
    var time: String? = nil
    var skipped: Bool = false
    var overrode: Bool = false
    var fromOnboarding: Bool = false

    init(id: String = Ids.make(), itemId: String, day: String, slot: String, at: String = "", time: String? = nil, overrode: Bool = false, fromOnboarding: Bool = false) {
        self.id = id; self.itemId = itemId; self.day = day; self.slot = slot; self.at = at; self.time = time; self.overrode = overrode; self.fromOnboarding = fromOnboarding
    }

    enum CodingKeys: String, CodingKey { case id, itemId, day, slot, at, time, skipped, overrode, fromOnboarding }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? Ids.make()
        itemId = try c.decode(String.self, forKey: .itemId)
        day = try c.decode(String.self, forKey: .day)
        slot = try c.decodeIfPresent(String.self, forKey: .slot) ?? "evening"
        at = try c.decodeIfPresent(String.self, forKey: .at) ?? ""
        time = try c.decodeIfPresent(String.self, forKey: .time)
        skipped = try c.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
        overrode = try c.decodeIfPresent(Bool.self, forKey: .overrode) ?? false
        fromOnboarding = try c.decodeIfPresent(Bool.self, forKey: .fromOnboarding) ?? false
    }
}

struct DiaryDay: Codable, Equatable, Hashable {
    var reactions: [String: Int] = [:]
    var note: String = ""
    var photos: [String] = []

    init(reactions: [String: Int] = [:], note: String = "", photos: [String] = []) { self.reactions = reactions; self.note = note; self.photos = photos }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reactions = (try? c.decodeIfPresent([String: Int].self, forKey: .reactions)) ?? [:]
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
    }
}

struct Reminders: Codable, Equatable, Hashable {
    struct Morning: Codable, Equatable, Hashable { var weekdays = "07:45"; var weekend = "09:30" }
    var morning = Morning()
    var evening = "22:00"
    /// Разовый сдвиг утра: "YYYY-MM-DD" → "HH:MM"
    var overrides: [String: String] = [:]
    /// Повтор, если пункт не отмечен (минуты, 0 — выкл). Нативная версия.
    var followUpMinutes: Int = 60
    var quietAfter: String = "23:30"

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        morning = try c.decodeIfPresent(Morning.self, forKey: .morning) ?? Morning()
        evening = try c.decodeIfPresent(String.self, forKey: .evening) ?? "22:00"
        overrides = try c.decodeIfPresent([String: String].self, forKey: .overrides) ?? [:]
        followUpMinutes = try c.decodeIfPresent(Int.self, forKey: .followUpMinutes) ?? 60
        quietAfter = try c.decodeIfPresent(String.self, forKey: .quietAfter) ?? "23:30"
    }
}

struct Settings: Codable, Equatable, Hashable {
    var pregnancy = false
    var rosacea = false
    var sensitive = false
    /// auto (стандартный; осторожный при розацеа или чувствительной коже) · standard · cautious
    var retinoidProfile = "auto"
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pregnancy = try c.decodeIfPresent(Bool.self, forKey: .pregnancy) ?? false
        rosacea = try c.decodeIfPresent(Bool.self, forKey: .rosacea) ?? false
        sensitive = try c.decodeIfPresent(Bool.self, forKey: .sensitive) ?? false
        retinoidProfile = try c.decodeIfPresent(String.self, forKey: .retinoidProfile) ?? "auto"
    }
    var cautious: Bool { retinoidProfile == "cautious" || (retinoidProfile == "auto" && (rosacea || sensitive)) }
    /// Лимит суммарной нагрузки активов за один приём.
    var loadLimit: Int { rosacea || sensitive ? 4 : 6 }
}

enum Ids {
    static func make() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<12).map { _ in chars.randomElement()! })
    }
}
