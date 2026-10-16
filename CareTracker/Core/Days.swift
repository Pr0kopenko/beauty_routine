import Foundation

// День ухода — строка "YYYY-MM-DD" в местном времени, день заканчивается в 04:00.
// Строки сравниваются лексикографически так же, как даты.

enum Days {
    static let dayStartHour = 4
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ru_RU")
        return c
    }()

    static func key(_ date: Date = Date(), calendar cal: Calendar = Days.calendar) -> String {
        var d = date
        if cal.component(.hour, from: d) < dayStartHour { d = cal.date(byAdding: .day, value: -1, to: d)! }
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func parts(_ key: String) -> (Int, Int, Int) {
        let p = key.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? (p[0], p[1], p[2]) : (1970, 1, 1)
    }

    /// Полдень дня — безопасно для арифметики при переходе на летнее время.
    static func noon(_ key: String, calendar cal: Calendar = Days.calendar) -> Date {
        let (y, m, d) = parts(key)
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    static func add(_ key: String, _ n: Int) -> String {
        let (y, m, d) = parts(key)
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(byAdding: .day, value: n, to: utc.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!)!
        let c = utc.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func between(_ from: String, _ to: String) -> Int {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let (y1, m1, d1) = parts(from), (y2, m2, d2) = parts(to)
        let a = utc.date(from: DateComponents(year: y1, month: m1, day: d1, hour: 12))!
        let b = utc.date(from: DateComponents(year: y2, month: m2, day: d2, hour: 12))!
        return Int((b.timeIntervalSince(a) / 86400).rounded())
    }

    /// 0 — воскресенье … 6 — суббота (как в JS).
    static func weekday(_ key: String) -> Int {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let (y, m, d) = parts(key)
        return utc.component(.weekday, from: utc.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!) - 1
    }

    static let weekdaysShort = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
    static let weekdaysAcc = ["в воскресенье", "в понедельник", "во вторник", "в среду", "в четверг", "в пятницу", "в субботу"]
    static let weekdaysFull = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
    static let monthsGen = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
    static let monthsNom = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]

    static func short(_ key: String) -> String {
        let (_, m, d) = parts(key)
        return "\(weekdaysShort[weekday(key)]),\u{00a0}\(d)\u{00a0}\(monthsGen[m - 1].prefix(3))"
    }
    static func long(_ key: String) -> String {
        let (_, m, d) = parts(key)
        return "\(weekdaysFull[weekday(key)]), \(d) \(monthsGen[m - 1])"
    }
    static func dayMonth(_ key: String) -> String {
        let (_, m, d) = parts(key)
        return "\(d)\u{00a0}\(monthsGen[m - 1])"
    }

    /// «сегодня», «завтра», «вчера», «в пятницу» (в пределах недели) или «пн, 20 окт».
    static func when(_ key: String, today: String) -> String {
        let diff = between(today, key)
        switch diff {
        case 0: return "сегодня"
        case 1: return "завтра"
        case -1: return "вчера"
        case 2..<7: return weekdaysAcc[weekday(key)]
        default: return short(key)
        }
    }

    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let a = abs(n) % 100, b = a % 10
        if a > 10 && a < 20 { return many }
        if b > 1 && b < 5 { return few }
        if b == 1 { return one }
        return many
    }
    static func daysWord(_ n: Int) -> String { "\(n)\u{00a0}\(plural(n, "день", "дня", "дней"))" }

    static func hhmm(_ date: Date = Date(), calendar cal: Calendar = Days.calendar) -> String {
        let c = cal.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }
}
