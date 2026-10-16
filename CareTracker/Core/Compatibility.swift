import Foundation

// Подсказки совместимости для отметки. Подсказка не запрещает отметку.

struct Hint: Equatable, Hashable { let rule: String; let text: String }

enum Compatibility {
    static func check(itemId: String, day: String, slot: String, in state: AppState) -> [Hint] {
        guard let item = state.item(itemId) else { return [] }
        let on = state.ruleOn
        let others = state.entries.filter { !($0.itemId == item.id && $0.day == day) && !$0.skipped }
        func items(on d: String, slot s: String? = nil) -> [Item] {
            let ids = Set(others.filter { $0.day == d && (s == nil || $0.slot == s) }.map(\.itemId))
            return state.items.filter { ids.contains($0.id) }
        }
        let sameEvening = slot == "evening" ? items(on: day, slot: "evening") : []
        let sameDay = items(on: day)
        let sameSlot = items(on: day, slot: slot)
        let names = { (list: [Item]) in list.map(\.name).joined(separator: ", ") }
        var out: [Hint] = []
        func add(_ rule: String, _ text: String) { if !out.contains(where: { $0.rule == rule }) { out.append(Hint(rule: rule, text: text)) } }
        func adjWord(_ d: String) -> String { d < day ? "Накануне (\(Days.short(d)))" : "На следующий день (\(Days.short(d)))" }

        if item.isRetinoid {
            if state.settings.pregnancy { add("pregnancy", "Включён режим беременности и ГВ — ретиноиды в это время не используют.") }
            if Retinoid.pause(state, today: day) != nil { add("pause", "Кожа сейчас реагирует. Ретиноид лучше отложить, пока она не успокоится.") }
            if on("retinoid-interval") {
                let freq = Catalog.frequency(item.schedule.freq)
                var st = state; st.entries = others
                let all = Retinoid.days(st)
                if let prev = all.last(where: { $0 < day }), Days.between(prev, day) < freq.minDays {
                    add("retinoid-interval", "До этого ретиноид был \(Days.short(prev)) — всего \(Days.daysWord(Days.between(prev, day))) назад, а по частоте нужно \(Days.daysWord(freq.minDays)). Можно с \(Days.short(Days.add(prev, freq.minDays))).")
                } else if let next = all.first(where: { $0 > day }), Days.between(day, next) < freq.minDays {
                    add("retinoid-interval", "Через \(Days.daysWord(Days.between(day, next))) уже отмечен ретиноид — интервал будет короче \(Days.daysWord(freq.minDays)).")
                } else if all.filter({ $0 >= Days.add(day, -6) && $0 < day }).count >= freq.maxPerWeek {
                    add("retinoid-interval", "За последние 7 дней ретиноид уже был \(freq.maxPerWeek) раз — это лимит этапа «\(freq.label.lowercased())».")
                }
            }
            if on("retinoid-evening") && slot == "morning" { add("retinoid-evening", "\(item.name) лучше наносить вечером: ретиноиды разрушаются на свету.") }
            let az = sameEvening.filter { $0.actives.contains("azelaic") }
            if on("retinoid-azelaic") && !az.isEmpty { add("retinoid-azelaic", "Сегодня вечером уже была \(names(az)). Пока кожа привыкает к ретиноиду, их лучше разнести. Вообще они сочетаются — это перестраховка.") }
            let ac = sameEvening.filter(\.hasAcid)
            if on("retinoid-acids") && !ac.isEmpty { add("retinoid-acids", "Сегодня вечером уже были кислоты (\(names(ac))). Ретиноид лучше в другой вечер.") }
            if on("retinoid-acids-adjacent") {
                for d in [Days.add(day, -1), Days.add(day, 1)] { if let a = items(on: d).first(where: \.hasAcid) { add("retinoid-acids-adjacent", "\(adjWord(d)) были кислоты (\(a.name)). Для чувствительной кожи лучше день отдыха между ними."); break } }
            }
        }
        if item.actives.contains("azelaic") && on("retinoid-azelaic") && slot == "evening" && sameEvening.contains(where: \.isRetinoid) {
            add("retinoid-azelaic", "Сегодня вечер ретиноида. Азелаиновую лучше утром, пока кожа привыкает. Вообще они сочетаются — это перестраховка.")
        }
        if item.hasAcid {
            if on("retinoid-acids") && slot == "evening" && sameEvening.contains(where: \.isRetinoid) { add("retinoid-acids", "Сегодня вечером был ретиноид. Кислоты лучше в другой вечер.") }
            if on("retinoid-acids-adjacent") {
                for d in [Days.add(day, -1), Days.add(day, 1)] where items(on: d).contains(where: \.isRetinoid) { add("retinoid-acids-adjacent", "\(adjWord(d)) был ретиноид. Кислоты лучше перенести, чтобы между ними был день отдыха."); break }
            }
            if on("acids-weekly") {
                let from = Days.add(day, -6)
                let acidDays = Set(others.filter { $0.day >= from && $0.day <= day && (state.item($0.itemId)?.hasAcid ?? false) }.map(\.day))
                if acidDays.count >= 2 { add("acids-weekly", "Кислоты за последние 7 дней уже были \(acidDays.count) раза. Лучше не чаще 2–3 раз в неделю.") }
            }
        }
        if Retinoid.pause(state, today: day) != nil && !item.isRetinoid && item.actives.contains(where: { Catalog.strongActives.contains($0) }) {
            add("pause", "Кожа сейчас реагирует. Активы лучше отложить на пару дней: мягкое очищение, увлажнение и SPF.")
        }

        func pair(_ id: String, _ mine: (Item) -> Bool, _ theirs: (Item) -> Bool, _ list: [Item], _ text: (String) -> String) {
            guard on(id), mine(item) else { return }
            let hit = list.filter(theirs)
            if !hit.isEmpty { add(id, text(names(hit))) }
        }
        let has = { (a: String) in { (i: Item) in i.actives.contains(a) } }
        pair("retinoid-bpo", \.isOxidizableRetinoid, has("bpo"), sameSlot) { "В это же время уже был бензоилпероксид (\($0)) — он окисляет ретиноид. Лучше БПО утром, ретиноид вечером." }
        pair("retinoid-bpo", has("bpo"), \.isOxidizableRetinoid, sameSlot) { "В это же время уже был ретиноид (\($0)) — бензоилпероксид его окисляет. Лучше утром." }
        pair("vitc-retinoid", has("vitc"), \.isRetinoid, sameSlot) { "В это же время был ретиноид (\($0)). Витамин C лучше утром." }
        pair("vitc-retinoid", \.isRetinoid, has("vitc"), sameSlot) { "В это же время был витамин C (\($0)). Удобнее: C утром, ретиноид вечером." }
        pair("vitc-acids", has("vitc"), \.hasAcid, sameSlot) { "В это же время были кислоты (\($0)). Витамин C лучше в другое время суток." }
        pair("vitc-acids", \.hasAcid, has("vitc"), sameSlot) { "В это же время был витамин C (\($0)). Кислоты лучше в другое время суток." }
        pair("vitc-bpo", has("vitc"), has("bpo"), sameSlot) { "В это же время был бензоилпероксид (\($0)) — он окисляет витамин C." }
        pair("vitc-bpo", has("bpo"), has("vitc"), sameSlot) { "В это же время был витамин C (\($0)) — бензоилпероксид его окисляет." }
        pair("bpo-acids", has("bpo"), \.hasAcid, sameDay) { "Сегодня уже были кислоты (\($0)). С бензоилпероксидом лучше в разные дни." }
        pair("bpo-acids", \.hasAcid, has("bpo"), sameDay) { "Сегодня уже был бензоилпероксид (\($0)). Кислоты лучше в другой день." }
        pair("one-exfoliant", \.isExfoliating, \.isExfoliating, sameDay) { "Сегодня уже была эксфолиация (\($0)). Одного раза в день достаточно — иначе легко пересушить кожу." }
        pair("copper-acids", has("copper"), { $0.hasAcid || $0.actives.contains("vitc") }, sameSlot) { "В это же время были кислоты или витамин C (\($0)). Медные пептиды лучше отдельно." }
        pair("copper-acids", { $0.hasAcid || $0.actives.contains("vitc") }, has("copper"), sameSlot) { "В это же время были медные пептиды (\($0)). Лучше в другое время суток." }
        return out
    }

    /// Как новое средство уживётся с набором — для экрана добавления.
    static func preview(actives: [String], in state: AppState, excluding id: String? = nil) -> [String] {
        let rest = state.items.filter { !$0.archived && $0.id != id }
        let hasRet = rest.contains(where: \.isRetinoid)
        let acid = actives.contains { Catalog.acidGroup.contains($0) }
        var out: [String] = []
        if actives.contains("retinoid") && hasRet { out.append("У тебя уже есть ретиноид — интервал считаю по обоим вместе.") }
        if acid && hasRet { out.append("Не в один вечер с ретиноидом.") }
        if acid { out.append("Кислоты — не чаще 2–3 раз в неделю.") }
        if actives.contains("azelaic") && hasRet { out.append("Пока вводишь ретиноид — лучше в другой вечер (перестраховка).") }
        if actives.contains("bpo") && hasRet { out.append("С ретиноидом — в разное время суток (кроме адапалена).") }
        if actives.contains("vitc") && hasRet { out.append("Витамин C — утром, ретиноид — вечером.") }
        if actives.contains("retinoid") { out.append("Только вечером, по графику введения.") }
        if out.isEmpty && !actives.isEmpty { out.append("С твоим набором конфликтов нет.") }
        return out
    }
}
