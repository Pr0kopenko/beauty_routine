import Foundation

// Что и когда напомнить. Чистая функция — сервис уведомлений только раскладывает результат
// по UNCalendarNotificationTrigger. Лимит iOS — 64 ожидающих уведомления, мы ставим ≤ 30.

struct PlannedReminder: Equatable, Hashable {
    let id: String          // m-2026-10-17, e-2026-10-17, f-m-2026-10-17 (повтор)
    let day: String
    let time: String        // HH:MM
    let kind: String        // morning · evening
    let title: String
    let body: String
    let followUp: Bool
}

enum NotificationPlanner {
    static func plan(_ state: AppState, today: String, now: String, days: Int = 14) -> [PlannedReminder] {
        guard state.onboarded else { return [] }
        var out: [PlannedReminder] = []
        for i in 0..<days {
            let day = Days.add(today, i)
            let p = Planner.plan(state, day: day, today: day)
            let morningItems = (p.morning + p.supplements).filter { !$0.done }
            let eveningItems = p.evening.filter { !$0.done }
            let mt = Planner.morningTime(state.reminders, day)
            if !morningItems.isEmpty && (i > 0 || now < mt) {
                let supp = p.supplements.filter { !$0.done }.map(\.item.name)
                let title = supp.isEmpty ? "Утренний уход" : "\(supp.joined(separator: ", ")) и утренний уход"
                var body = morningItems.map(\.item.name).prefix(4).joined(separator: ", ")
                if p.spfAccent { body = "После вчерашнего ретиноида или кислот — SPF обязательно. " + body }
                out.append(PlannedReminder(id: "m-\(day)", day: day, time: mt, kind: "morning", title: title, body: body, followUp: false))
                if state.reminders.followUpMinutes > 0, let f = add(mt, state.reminders.followUpMinutes), f < state.reminders.quietAfter, i < 2 {
                    out.append(PlannedReminder(id: "f-m-\(day)", day: day, time: f, kind: "morning", title: title, body: "Ещё не отмечено: \(body)", followUp: true))
                }
            }
            let et = state.reminders.evening
            if !eveningItems.isEmpty && (i > 0 || now < et) {
                var title = "Вечерний уход"
                if let r = p.retinoid, [.today, .overdue, .notStarted].contains(r.status.state) { title = "Сегодня вечер — \(r.item.name)" }
                if p.paused { title = "Вечер без активов: кожа отдыхает" }
                let body = eveningItems.map(\.item.name).prefix(4).joined(separator: ", ")
                out.append(PlannedReminder(id: "e-\(day)", day: day, time: et, kind: "evening", title: title, body: body, followUp: false))
                if state.reminders.followUpMinutes > 0, let f = add(et, state.reminders.followUpMinutes), f < state.reminders.quietAfter, i < 2 {
                    out.append(PlannedReminder(id: "f-e-\(day)", day: day, time: f, kind: "evening", title: title, body: "Ещё не отмечено: \(body)", followUp: true))
                }
            }
        }
        return Array(out.prefix(30))
    }

    static func add(_ hhmm: String, _ minutes: Int) -> String? {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return nil }
        let t = p[0] * 60 + p[1] + minutes
        guard t < 24 * 60 else { return nil }
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}
