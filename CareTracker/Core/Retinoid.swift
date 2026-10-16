import Foundation

// Статус ретиноида, график введения, пауза по реакции кожи.
// Интервал считается по ретиноиду как активу: если ретиноидов несколько,
// любой из них сбрасывает счётчик (два разных ретиноида в соседние вечера — тоже нагрузка).

enum RetinoidState: String, Equatable { case notStarted, done, resting, today, overdue, paused, blocked }

struct Pause: Equatable { let level: Int; let since: String; let until: String }

struct RetinoidStatus: Equatable {
    let state: RetinoidState
    let minDays: Int
    let last: String?
    let since: Int?
    let next: String?
    var pause: Pause? = nil
}

struct Advice: Equatable {
    enum Kind: String { case up, down, doctor }
    let kind: Kind
    let text: String
    let to: String
}

enum Retinoid {
    /// Дни с нанесением любого ретиноида (без пропусков).
    static func days(_ state: AppState, through day: String? = nil) -> [String] {
        let ids = Set(state.items.filter(\.isRetinoid).map(\.id))
        let set = Set(state.entries.filter { ids.contains($0.itemId) && !$0.skipped && (day == nil || $0.day <= day!) }.map(\.day))
        return set.sorted()
    }

    static func status(_ item: Item, _ state: AppState, today: String) -> RetinoidStatus {
        let freq = Catalog.frequency(item.schedule.freq)
        let all = days(state)
        let last = all.last { $0 <= today }
        let since = last.map { Days.between($0, today) }
        if state.settings.pregnancy { return RetinoidStatus(state: .blocked, minDays: freq.minDays, last: last, since: since, next: nil) }
        if since == 0 {
            return RetinoidStatus(state: .done, minDays: freq.minDays, last: last, since: 0, next: nextAllowed(freq: freq, days: all, from: Days.add(today, 1)))
        }
        if let p = pause(state, today: today) {
            return RetinoidStatus(state: .paused, minDays: freq.minDays, last: last, since: since, next: p.until, pause: p)
        }
        guard let lastDay = last, let s = since else { return RetinoidStatus(state: .notStarted, minDays: freq.minDays, last: nil, since: nil, next: today) }
        let next = nextAllowed(freq: freq, days: all, from: today)
        if next > today { return RetinoidStatus(state: .resting, minDays: freq.minDays, last: lastDay, since: s, next: next) }
        if s <= freq.minDays + 2 { return RetinoidStatus(state: .today, minDays: freq.minDays, last: lastDay, since: s, next: today) }
        return RetinoidStatus(state: .overdue, minDays: freq.minDays, last: lastDay, since: s, next: today)
    }

    /// Ближайший день ≥ from: интервал от последнего раза и лимит в неделю.
    static func nextAllowed(freq: Frequency, days: [String], from: String) -> String {
        var d = from
        for _ in 0..<30 {
            let before = days.filter { $0 < d }
            if let lastB = before.last, Days.between(lastB, d) < freq.minDays { d = Days.add(d, 1); continue }
            let weekStart = Days.add(d, -6)
            if days.filter({ $0 >= weekStart && $0 < d }).count >= freq.maxPerWeek { d = Days.add(d, 1); continue }
            return d
        }
        return Days.add(from, freq.minDays)
    }

    /// Раздражение = покраснение, сухость, жжение (высыпания — отдельно: может быть пурджинг).
    static func irritation(_ state: AppState, _ day: String) -> Int? {
        guard let r = state.diary[day]?.reactions, !r.isEmpty else { return nil }
        let v = ["redness", "dryness", "burning"].compactMap { r[$0] }
        return v.isEmpty ? (r["breakouts"] != nil ? 0 : nil) : v.max()
    }

    /// Пауза: «средне» — 3 дня от реакции; «сильно» — пока не будет записи с раздражением ≤ слабо (смотрим до 21 дня назад).
    static func pause(_ state: AppState, today: String) -> Pause? {
        for i in 0...21 {
            let d = Days.add(today, -i)
            guard let l = irritation(state, d) else { continue }
            if l >= 3 {
                for j in stride(from: i - 1, through: 0, by: -1) {
                    if let lj = irritation(state, Days.add(today, -j)), lj <= 1 { return nil }
                }
                return Pause(level: 3, since: d, until: Days.add(today, 1))
            }
            if l == 2 && i < 3 { return Pause(level: 2, since: d, until: Days.add(d, 3)) }
            if l <= 1 && i < 3 { return nil } // свежая спокойная запись
        }
        return nil
    }

    static func advice(_ item: Item, _ state: AppState, today: String) -> Advice? {
        guard item.isIntervalRetinoid, !state.settings.pregnancy else { return nil }
        let form = item.form
        let cur = item.schedule.freq ?? "2w"
        guard let idx = Catalog.stageOrder.firstIndex(of: cur) else { return nil }
        let p = pause(state, today: today)
        if p?.level == 3 {
            return Advice(kind: .doctor, text: "Сильная реакция. Пауза во всех активах, пока кожа не успокоится, потом заново с 2 раз в неделю. Если не проходит за несколько дней — покажись дерматологу.", to: "2w")
        }
        if let p, p.level == 2 {
            guard idx > 1 else { return nil }
            let to = Catalog.stageOrder[idx - 1]
            return Advice(kind: .down, text: "Кожа реагирует. Пауза до \(Days.short(p.until)), а потом лучше шаг назад — \(Catalog.frequency(to).label.lowercased()).", to: to)
        }
        if form.rx || idx >= Catalog.stageOrder.count - 1 { return nil }
        let all = days(state)
        guard let since = item.schedule.since ?? all.first else { return nil }
        if let s = item.schedule.snoozeUntil, s > today { return nil }
        let length = Days.between(since, today)
        let apps = all.filter { $0 >= since && $0 <= today }.count
        var worst = 0
        for i in 0..<7 { if let l = irritation(state, Days.add(today, -i)), l > worst { worst = l } }
        if length >= form.weeks * 7 && apps >= 3 && worst < 2 {
            let to = Catalog.stageOrder[idx + 1]
            return Advice(kind: .up, text: "\(Days.daysWord(length)) на частоте «\(Catalog.frequency(cur).label.lowercased())» без заметных реакций. Можно перейти на «\(Catalog.frequency(to).label.lowercased())».", to: to)
        }
        return nil
    }

    static func statusText(_ item: Item, _ st: RetinoidStatus, today: String) -> (title: String, sub: String) {
        let n = item.name
        switch st.state {
        case .notStarted: return ("\(n): можно начать сегодня", "Отметь, когда нанесёшь, — дальше посчитаю сама.")
        case .done: return ("\(n) нанесён ✓", "Следующий — \(Days.when(st.next!, today: today)), \(Days.dayMonth(st.next!)).")
        case .resting: return ("\(n) отдыхает", "Был \(Days.when(st.last!, today: today)). Следующий — \(Days.when(st.next!, today: today)) вечером.")
        case .today: return ("Сегодня вечер — \(n)", "Прошло \(Days.daysWord(st.since!)) — можно.")
        case .overdue: return ("\(n) ждёт уже \(Days.daysWord(st.since!))", "Можно сегодня вечером.")
        case .paused: return ("\(n): пауза", st.pause?.level == 3 ? "Кожа сильно реагирует. Ждём, пока успокоится." : "Кожа реагирует. Отдыхаем до \(Days.short(st.next!)).")
        case .blocked: return ("\(n) на паузе", "Включён режим беременности и ГВ — ретиноиды не планирую.")
        }
    }

    /// Короткий заголовок экрана «Сегодня».
    static func headline(_ item: Item, _ st: RetinoidStatus, today: String) -> String {
        switch st.state {
        case .resting: return "\(item.name) — \(Days.when(st.next!, today: today))"
        case .today, .overdue: return "Сегодня вечер — \(item.name)"
        case .done: return "\(item.name) нанесён ✓"
        case .paused: return "Пауза: кожа отдыхает"
        case .blocked: return "Ретиноиды на паузе"
        case .notStarted: return "\(item.name) — можно начать"
        }
    }
}
