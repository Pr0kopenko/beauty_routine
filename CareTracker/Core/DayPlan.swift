import Foundation

// План дня: блоки утро / добавки / вечер / по желанию.

struct PlanRow: Equatable, Identifiable {
    var id: String { item.id }
    let item: Item
    let done: Bool
    let entry: Entry?
    var deferred: String? = nil
    var accent: String? = nil
    var status: RetinoidStatus? = nil
}

struct DayPlan: Equatable {
    var morning: [PlanRow] = []
    var supplements: [PlanRow] = []
    var evening: [PlanRow] = []
    var optional: [PlanRow] = []
    var retinoid: (item: Item, status: RetinoidStatus)? = nil
    var spfAccent = false
    var paused = false

    static func == (a: DayPlan, b: DayPlan) -> Bool {
        a.morning == b.morning && a.supplements == b.supplements && a.evening == b.evening && a.optional == b.optional && a.spfAccent == b.spfAccent && a.paused == b.paused
    }
    var scheduled: [PlanRow] { morning + supplements + evening }
    var allDone: Bool { !scheduled.isEmpty && scheduled.allSatisfy(\.done) }
}

enum Planner {
    static func plan(_ state: AppState, day: String, today: String? = nil) -> DayPlan {
        let today = today ?? day
        let active = state.items.filter { !$0.archived }
        let dayEntries = state.entries.filter { $0.day == day && !$0.skipped }
        let doneIds = Set(dayEntries.map(\.itemId))
        var p = DayPlan()

        let retinoids = active.filter(\.isIntervalRetinoid)
        let statuses = retinoids.map { ($0, Retinoid.status($0, state, today: day)) }
        if let first = statuses.first(where: { !doneIds.contains($0.0.id) || true }) { p.retinoid = (first.0, first.1) }
        let retinoidTonight = statuses.contains { [.today, .overdue, .done, .notStarted].contains($0.1.state) }
        p.paused = statuses.contains { $0.1.state == .paused } || (retinoids.isEmpty && Retinoid.pause(state, today: day) != nil)

        let yesterday = Days.add(day, -1)
        let yIds = Set(state.entries.filter { $0.day == yesterday && !$0.skipped }.map(\.itemId))
        let strongYesterday = active.filter { yIds.contains($0.id) && ($0.isRetinoid || $0.hasAcid) }
        p.spfAccent = state.ruleOn("spf-after") && !strongYesterday.isEmpty

        for item in active {
            let entry = dayEntries.first { $0.itemId == item.id }
            var row = PlanRow(item: item, done: doneIds.contains(item.id), entry: entry)
            if item.isIntervalRetinoid {
                let st = statuses.first { $0.0.id == item.id }!.1
                row.status = st
                if !row.done {
                    switch st.state {
                    case .resting: row.deferred = "Отдыхает до \(Days.when(st.next!, today: today))"
                    case .paused: row.deferred = "Пауза: кожа реагирует"
                    case .blocked: row.deferred = "Режим беременности и ГВ"
                    default: break
                    }
                }
                if row.deferred != nil { p.optional.append(row) } else { p.evening.insert(row, at: 0) }
                continue
            }
            if item.actives.contains("spf") && p.spfAccent {
                row.accent = "После \(strongYesterday.contains(where: \.isRetinoid) ? "вчерашнего ретиноида" : "вчерашних кислот") кожа чувствительнее к солнцу"
            }
            let block = item.block
            if p.paused && !row.done && item.actives.contains(where: { Catalog.strongActives.contains($0) }) {
                row.deferred = "Пауза: кожа реагирует — активы потом"
                p.optional.append(row); continue
            }
            let conflictsTonight = retinoidTonight && (
                (state.ruleOn("retinoid-azelaic") && item.actives.contains("azelaic")) ||
                (state.ruleOn("retinoid-acids") && item.hasAcid))
            if conflictsTonight && !row.done && (block == "evening" || block == "optional") {
                row.deferred = "Не сегодня: вечер ретиноида"
                p.optional.append(row); continue
            }
            if block == "optional" && row.done { if entry?.slot == "morning" { p.morning.append(row) } else { p.evening.append(row) }; continue }
            switch block {
            case "morning": p.morning.append(row)
            case "evening": p.evening.append(row)
            case "supplements": p.supplements.append(row)
            default: p.optional.append(row)
            }
        }
        p.optional.sort { ($0.deferred == nil ? 0 : 1) < ($1.deferred == nil ? 0 : 1) }
        return p
    }

    static func defaultSlot(_ item: Item, hour: Int) -> String {
        if item.block == "morning" || item.block == "supplements" { return "morning" }
        if item.block == "evening" || item.isRetinoid { return "evening" }
        return hour >= Days.dayStartHour && hour < 15 ? "morning" : "evening"
    }

    static func count(_ itemId: String, _ entries: [Entry], from: String, to: String) -> Int {
        Set(entries.filter { $0.itemId == itemId && !$0.skipped && $0.day >= from && $0.day <= to }.map(\.day)).count
    }

    static func morningTime(_ r: Reminders, _ day: String) -> String {
        if let o = r.overrides[day] { return o }
        let wd = Days.weekday(day)
        return wd == 0 || wd == 6 ? r.morning.weekend : r.morning.weekdays
    }

    static func recentProducts(_ state: AppState, _ day: String) -> [Item] {
        let days = [day, Days.add(day, -1)]
        var seen = Set<String>()
        return state.entries.filter { !$0.skipped && days.contains($0.day) }.compactMap { e in
            guard !seen.contains(e.itemId), let it = state.item(e.itemId) else { return nil }
            seen.insert(e.itemId); return it
        }
    }

    static func firstUse(_ state: AppState) -> [String: String] {
        var m: [String: String] = [:]
        for e in state.entries where !e.skipped && !e.fromOnboarding { if m[e.itemId] == nil || e.day < m[e.itemId]! { m[e.itemId] = e.day } }
        return m
    }

    static func reactionLevel(_ state: AppState, _ day: String) -> Int? { state.diary[day]?.reactions.values.max() }

    static func streak(_ itemId: String, _ state: AppState, today: String, includeToday: Bool) -> Int {
        let days = Set(state.entries.filter { $0.itemId == itemId && !$0.skipped }.map(\.day))
        var d = includeToday ? today : Days.add(today, -1)
        var n = 0
        while days.contains(d) { n += 1; d = Days.add(d, -1) }
        return n
    }
}
