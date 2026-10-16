import Foundation

// Изменения состояния без UI: отметки, новые средства, онбординг.
// AppStore вызывает эти функции и сохраняет результат; тесты проверяют их на Linux.

enum Actions {
    /// Новая отметка. Время ставим, только если отмечают «сейчас» (сегодня и в текущей половине дня).
    static func entry(itemId: String, day: String, slot: String, now: Date = Date(), overrode: Bool = false) -> Entry {
        let hour = Days.calendar.component(.hour, from: now)
        let period = hour >= Days.dayStartHour && hour < 15 ? "morning" : "evening"
        let time = day == Days.key(now) && slot == period ? Days.hhmm(now) : nil
        return Entry(itemId: itemId, day: day, slot: slot, at: ISO8601DateFormatter().string(from: now), time: time, overrode: overrode)
    }

    /// «Сделала» для блока из уведомления или кнопки «Отметить всё».
    /// Пропускает отложенное и то, на что есть подсказка совместимости, — это решают вручную.
    static func markBlock(_ state: inout AppState, kind: String, day: String, now: Date = Date()) -> [Entry] {
        let p = Planner.plan(state, day: day, today: day)
        let rows: [PlanRow]
        switch kind {
        case "morning": rows = p.morning + p.supplements
        case "supplements": rows = p.supplements
        default: rows = p.evening
        }
        let slot = kind == "evening" ? "evening" : "morning"
        var added: [Entry] = []
        for r in rows where !r.done && r.deferred == nil {
            if !Compatibility.check(itemId: r.item.id, day: day, slot: slot, in: state).isEmpty { continue }
            let e = entry(itemId: r.item.id, day: day, slot: slot, now: now)
            state.entries.append(e); added.append(e)
        }
        return added
    }

    /// «Сегодня пропускаю»: пропуск фиксируется, чтобы не напоминать повторно. В интервал ретиноида пропуск не идёт.
    static func skipBlock(_ state: inout AppState, kind: String, day: String, now: Date = Date()) {
        let p = Planner.plan(state, day: day, today: day)
        let rows = kind == "evening" ? p.evening : p.morning + p.supplements
        for r in rows where !r.done {
            var e = entry(itemId: r.item.id, day: day, slot: kind == "evening" ? "evening" : "morning", now: now)
            e.skipped = true
            state.entries.append(e)
        }
    }

    static func block(time: String, type: String, actives: [String]) -> String {
        if actives.contains("supplement") || type == "supplement" { return "supplements" }
        if type == "spf" || time == "morning" { return "morning" }
        if actives.contains("retinoid") || time == "evening" { return "evening" }
        return "optional"
    }

    /// Средство из распознавания или ручного ввода. Ретиноид сразу получает график по своей форме.
    static func makeItem(_ r: RecognizedProduct, block: String? = nil, thumb: String? = nil, today: String) -> Item {
        let isRet = r.actives.contains("retinoid")
        let form = isRet ? (r.retinoidForm ?? "retinol") : nil
        let b = block ?? self.block(time: r.time, type: r.type, actives: r.actives)
        let finalBlock = isRet && b != "optional" ? "evening" : b
        let schedule: Schedule
        if isRet { schedule = Schedule(type: "interval", freq: (Catalog.retinoidForms[form!] ?? Catalog.retinoidForms["retinol"]!).start, since: today) }
        else { schedule = Schedule(type: finalBlock == "optional" ? "asneeded" : "daily") }
        let name = r.displayName.isEmpty ? "Новое средство" : r.displayName
        let type = r.type == "other" && r.actives.contains("supplement") ? "supplement" : r.type
        var it = Item(id: Ids.make(), name: name, actives: r.actives, block: finalBlock, schedule: schedule, type: type, retinoidForm: form)
        it.brand = r.brand; it.strength = r.strength; it.composition = r.composition; it.note = r.note; it.thumb = thumb; it.createdAt = today
        return it
    }

    /// Ответы онбординга.
    struct Onboarding: Equatable {
        /// "1", "3", "7" — дней назад; "date"; "never"; nil — нет ретиноида
        var last: String? = nil
        var date: String? = nil
        var freq: String? = nil
        var weekdays = "07:45"
        var weekend = "09:30"
        var evening = "22:00"
    }

    static func lastRetinoidDay(_ o: Onboarding, today: String) -> String? {
        guard let last = o.last, last != "never" else { return nil }
        if last == "date" { return o.date ?? Days.add(today, -4) }
        return Int(last).map { Days.add(today, -$0) }
    }

    /// Применяет онбординг: график ретиноида, «последний раз», время напоминаний.
    static func applyOnboarding(_ state: AppState, _ o: Onboarding, today: String) -> AppState {
        var s = state
        s.entries.removeAll { $0.fromOnboarding }
        if let i = s.items.firstIndex(where: { $0.isRetinoid && !$0.archived }) {
            let form = s.items[i].form
            let freq = o.freq ?? s.items[i].schedule.freq ?? (o.last == "never" ? form.start : "2w")
            s.items[i].block = "evening"
            s.items[i].schedule = Schedule(type: "interval", freq: freq, since: today)
            if let d = lastRetinoidDay(o, today: today) {
                s.entries.append(Entry(itemId: s.items[i].id, day: d, slot: "evening", fromOnboarding: true))
            }
        }
        s.reminders.morning = Reminders.Morning(weekdays: o.weekdays, weekend: o.weekend)
        s.reminders.evening = o.evening
        s.startedAt = s.startedAt ?? today
        return s
    }

    /// Переход на новый этап частоты (совет «шаг вверх / вниз»).
    static func applyFrequency(_ state: inout AppState, itemId: String, freq: String, today: String) {
        guard let i = state.items.firstIndex(where: { $0.id == itemId }) else { return }
        state.items[i].schedule.freq = freq
        state.items[i].schedule.since = today
        state.items[i].schedule.snoozeUntil = nil
    }

    /// Дни с отметками за месяц — для истории.
    static func monthDays(_ state: AppState, year: Int, month: Int) -> [String: [Entry]] {
        let prefix = String(format: "%04d-%02d-", year, month)
        return Dictionary(grouping: state.entries.filter { $0.day.hasPrefix(prefix) && !$0.skipped }, by: \.day)
    }
}
