import Foundation

// Локальная база активов (Resources/ingredients-kb.json): разбор состава, концентрация,
// карточка «что с этим делать», сочетания с набором. Работает без интернета.

struct KB: Decodable {
    struct Concentration: Decodable { let low: Double?; let medium: Double?; let high: Double?; let notes: String? }
    struct Active: Decodable, Hashable {
        let id: String
        let nameRu: String
        let group: String
        let inci: [String]
        let strength: Int
        let concentration: Concentration?
        let timeOfDay: String
        let photosensitizing: Bool
        let spfRequired: Bool
        let pregnancy: String
        let startFrequency: String
        let maxFrequency: String
        let stepUpWeeks: Int?
        let sensitiveSkin: String
        let notes: String
        let sources: [String]
        let evidence: String?
        let patterns: [String]?
        let activeOnlyIfAbove1pctLine: Bool?
        static func == (a: Active, b: Active) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }
    struct Pair: Decodable { let a: String; let b: String; let verdict: String; let why: String; let confidence: String; let condition: String?; let myth: Bool?; let sources: [String] }
    struct Source: Decodable, Hashable { let id: String; let title: String; let url: String }
    struct Marker: Decodable { let inci: String; let maxPct: Double? }

    let actives: [Active]
    let pairs: [Pair]
    let sources: [Source]
    let concentrationMarkers: [Marker]
}

/// Найденный в составе актив.
struct FoundActive: Hashable {
    enum Level: String { case low, medium, high, veryHigh, unknown }
    let active: KB.Active
    var pct: Double?
    var level: Level
    var position: Int?
    var fromComposition: Bool
    /// Раздражающий потенциал с поправкой на концентрацию (1…5).
    var strength: Int

    var levelText: String {
        switch level {
        case .low: return "низкая концентрация"
        case .medium: return "средняя концентрация"
        case .high: return "высокая концентрация"
        case .veryHigh: return "очень высокая концентрация"
        case .unknown: return "концентрация неизвестна"
        }
    }
}

enum Knowledge {
    static let kb: KB = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "ingredients-kb", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let kb = try? JSONDecoder().decode(KB.self, from: data) else {
            return KB(actives: [], pairs: [], sources: [], concentrationMarkers: [])
        }
        return kb
    }()

    static let byId: [String: KB.Active] = Dictionary(kb.actives.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    static func active(_ id: String) -> KB.Active? { byId[id] }
    static func source(_ id: String) -> KB.Source? { kb.sources.first { $0.id == id } }

    /// Шаблоны поиска: каждое INCI-название и русское имя, по границам слов; длинные — первыми.
    private static let matchers: [(regex: NSRegularExpression, id: String, length: Int)] = {
        var out: [(NSRegularExpression, String, Int)] = []
        for a in kb.actives {
            var names = Set(a.inci.map { $0.lowercased() })
            let ru = a.nameRu.lowercased().replacingOccurrences(of: #"\s*\(.*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            if ru.count >= 5 { names.insert(ru) }
            for n in names where n.count >= 3 {
                let p = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: n) + "(?![\\p{L}\\p{N}])"
                if let r = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) { out.append((r, a.id, n.count)) }
            }
            for p in a.patterns ?? [] {
                if let r = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) { out.append((r, a.id, 4)) }
            }
        }
        return out.sorted { $0.2 > $1.2 }
    }()

    // MARK: — состав

    static func tokens(_ text: String) -> [String] {
        var t = text
        if let colon = t.firstIndex(of: ":"), t.distance(from: t.startIndex, to: colon) < 40 { t = String(t[t.index(after: colon)...]) }
        return t.replacingOccurrences(of: "\n", with: ",")
            .split(whereSeparator: { ",;•·".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }
    }

    /// Разбор состава (INCI) или текста с упаковки: активы, проценты, уровень концентрации.
    static func analyze(_ text: String) -> [FoundActive] {
        let toks = tokens(text)
        guard !toks.isEmpty else { return [] }
        let markers = kb.concentrationMarkers.map { $0.inci.lowercased() }
        let line = toks.firstIndex { t in let l = t.lowercased(); return markers.contains { l.contains($0) } }
        var firstPos: [String: Int] = [:]
        for (i, tok) in toks.enumerated() {
            let ns = tok as NSString
            var taken: [NSRange] = []
            for m in matchers {
                guard let r = m.regex.firstMatch(in: tok, range: NSRange(location: 0, length: ns.length)) else { continue }
                if taken.contains(where: { NSIntersectionRange($0, r.range).length > 0 }) { continue }
                taken.append(r.range)
                if firstPos[m.id] == nil { firstPos[m.id] = i }
            }
        }
        let lower = text.lowercased()
        var out: [FoundActive] = []
        for (id, pos) in firstPos {
            guard let a = byId[id] else { continue }
            if a.activeOnlyIfAbove1pctLine == true, let line, pos > line { continue } // регулятор pH, а не актив
            let pct = explicitPercent(for: a, in: lower)
            var level: FoundActive.Level = .unknown
            if let pct { level = self.level(pct, a.concentration) }
            else if let line, pos > line, (a.concentration?.low ?? 0) >= 1 { level = .low }
            out.append(FoundActive(active: a, pct: pct, level: level, position: pos, fromComposition: true, strength: adjusted(a.strength, level)))
        }
        return out.sorted { ($0.strength, -($0.position ?? 0)) > ($1.strength, -($1.position ?? 0)) }
    }

    static func explicitPercent(for a: KB.Active, in lower: String) -> Double? {
        let num = #"(\d+(?:[.,]\d+)?)\s*%"#
        for n in a.inci.map({ $0.lowercased() }) where n.count >= 3 {
            let e = NSRegularExpression.escapedPattern(for: n)
            for p in [e + #"\s*[\(\-–:]?\s*"# + num, num + #"\s*"# + e] {
                guard let r = try? NSRegularExpression(pattern: p), let m = r.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                      let range = Range(m.range(at: 1), in: lower) else { continue }
                if let v = Double(lower[range].replacingOccurrences(of: ",", with: ".")), v > 0, v <= 100 { return v }
            }
        }
        return nil
    }

    static func level(_ pct: Double, _ c: KB.Concentration?) -> FoundActive.Level {
        guard let c, let low = c.low, let med = c.medium, let high = c.high else { return .unknown }
        if pct <= low { return .low }
        if pct <= med { return .medium }
        if pct <= high { return .high }
        return .veryHigh
    }

    static func adjusted(_ base: Int, _ level: FoundActive.Level) -> Int {
        let mod: Int
        switch level { case .low: mod = -1; case .high: mod = 1; case .veryHigh: mod = 2; default: mod = 0 }
        return min(5, max(1, base + mod))
    }

    // MARK: — связь с грубыми активами приложения

    /// Если состава нет — представитель группы по отмеченному активу.
    static func representative(_ coarse: String, form: String?) -> String? {
        switch coarse {
        case "retinoid": return form == "tazarotene" ? "tretinoin" : (form ?? "retinol")
        case "aha": return "glycolic_acid"
        case "bha": return "salicylic_acid"
        case "pha": return "gluconolactone"
        case "azelaic": return "azelaic_acid"
        case "niacinamide": return "niacinamide"
        case "vitc": return "vitc_laa"
        case "peptides": return "peptides_other"
        case "copper": return "copper_peptides"
        case "exfoliant": return "enzymes"
        case "bpo": return "benzoyl_peroxide"
        case "spf": return "spf_mineral"
        default: return nil
        }
    }

    /// Грубый актив приложения (для правил и цветов) по найденному.
    static func coarse(_ a: KB.Active) -> String? {
        let always = ["niacinamide": "niacinamide", "peptides": "peptides", "spf_filter": "spf"]
        if let c = always[a.group] { return c }
        guard a.strength >= 2 else { return nil }
        switch a.group {
        case "retinoid": return "retinoid"
        case "aha": return "aha"
        case "bha": return "bha"
        case "pha": return "pha"
        case "azelaic": return "azelaic"
        case "vitc": return "vitc"
        case "copper_peptides": return "copper"
        case "bpo": return "bpo"
        case "exfoliant_physical", "enzyme": return "exfoliant"
        default: return nil
        }
    }

    static func coarseActives(_ found: [FoundActive]) -> [String] {
        var out: [String] = []
        for f in found { if let c = coarse(f.active), !out.contains(c) { out.append(c) } }
        return out
    }

    static func retinoidForm(_ found: [FoundActive]) -> String? {
        found.first { $0.active.group == "retinoid" }?.active.id
    }

    /// Активы средства: из состава, иначе по отмеченным активам.
    static func ingredients(of item: Item) -> [FoundActive] {
        var found = item.composition.count > 10 ? analyze(item.composition) : []
        let have = Set(found.compactMap { coarse($0.active) })
        for c in item.actives where !have.contains(c) {
            guard let id = representative(c, form: item.retinoidForm), let a = byId[id] else { continue }
            let pct = parsePercent(item.strength)
            let lvl = pct.map { level($0, a.concentration) } ?? .unknown
            found.append(FoundActive(active: a, pct: pct, level: lvl, position: nil, fromComposition: false, strength: adjusted(a.strength, lvl)))
        }
        return found.sorted { $0.strength > $1.strength }
    }

    static func parsePercent(_ s: String) -> Double? {
        guard let r = try? NSRegularExpression(pattern: #"(\d+(?:[.,]\d+)?)\s*%"#), let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(m.range(at: 1), in: s) else { return nil }
        return Double(s[range].replacingOccurrences(of: ",", with: "."))
    }

    /// Нагрузка средства за приём: сумма сил активов (сила ≥ 2).
    static func load(of item: Item) -> Int {
        ingredients(of: item).filter { $0.strength >= 2 }.reduce(0) { $0 + $1.strength }
    }

    // MARK: — пары и частоты

    static let verdictRank = ["avoid_same_time": 5, "separate_slots": 4, "alternate_days": 3, "caution": 2, "ok": 1, "good_together": 0]
    static let verdictText = ["avoid_same_time": "Не в одно нанесение", "separate_slots": "Разнести на утро и вечер", "alternate_days": "В разные дни",
                              "caution": "Осторожно вместе", "ok": "Можно вместе", "good_together": "Хорошо вместе"]

    static func pair(_ a: KB.Active, _ b: KB.Active) -> KB.Pair? {
        let keysA = [a.id, a.group], keysB = [b.id, b.group]
        for ka in keysA { for kb2 in keysB {
            if let p = kb.pairs.first(where: { ($0.a == ka && $0.b == kb2) || ($0.a == kb2 && $0.b == ka) }) { return p }
        } }
        return nil
    }

    static let frequencyRank = ["1w": 0, "2w": 1, "3w": 2, "eod": 3, "5w": 4, "daily": 5, "2xdaily": 6]
    static func appFrequency(_ f: String) -> String? {
        switch f { case "2xdaily": return "daily"; case "asneeded": return nil; default: return Catalog.frequencies[f] != nil ? f : nil }
    }

    /// Стартовая частота для нового не-ретиноида: самая осторожная среди сильных активов.
    static func startFrequency(actives: [String], composition: String) -> String? {
        var it = Item(id: "", name: "", actives: actives)
        it.composition = composition
        let strong = ingredients(of: it).filter { $0.strength >= 2 && $0.active.group != "retinoid" }
        let freqs = strong.compactMap { appFrequency($0.active.startFrequency) }
        return freqs.min { (frequencyRank[$0] ?? 9) < (frequencyRank[$1] ?? 9) }
    }
}

// MARK: — карточка средства

struct CardLine: Hashable {
    let text: String
    /// manufacturer · leaflet · doctor · cosmetologist · user · ai · kb (общее правило по составу)
    let source: String
    var confidence: String? = nil
}

struct CompatNote: Hashable, Identifiable {
    var id: String { otherId + verdict }
    let otherId: String
    let otherName: String
    let verdict: String
    let why: String
    let confidence: String
    let condition: String?
    let myth: Bool
}

struct ProductCard {
    var found: [FoundActive] = []
    var fromComposition = false
    var isSupplement = false
    var time: CardLine?
    var intro: CardLine?
    /// Есть надёжная схема (своя / производитель) или схема не нужна (мягкое средство).
    var scheduleKnown = true
    var compat: [CompatNote] = []
    var myths: [CompatNote] = []
    var rosacea: [String] = []
    var triggers: [String] = []
    var sensitive: [String] = []
    var safety: [CardLine] = []
    var expect: [String] = []
    var sources: [KB.Source] = []
    var load = 0
}

enum CardBuilder {
    static func build(_ item: Item, in state: AppState) -> ProductCard {
        var c = ProductCard()
        c.isSupplement = item.actives.contains("supplement") || item.type == "supplement"
        if c.isSupplement {
            c.time = CardLine(text: "Время и доза — как на этикетке.", source: "kb")
            c.intro = CardLine(text: "Введения не требуется. Если принимаешь лекарства — сочетание уточни у врача.", source: "kb")
            return c
        }
        let found = Knowledge.ingredients(of: item)
        c.found = found
        c.fromComposition = found.contains { $0.fromComposition }
        c.load = found.filter { $0.strength >= 2 }.reduce(0) { $0 + $1.strength }
        let strong = found.filter { $0.strength >= 2 }

        // Когда
        let plan = item.introPlan
        var tod = plan?.timeOfDay
        if tod == nil {
            if item.isRetinoid || strong.contains(where: { $0.active.timeOfDay == "evening" }) { tod = "evening" }
            else if found.contains(where: { $0.active.group == "spf_filter" }) || item.type == "spf" || strong.contains(where: { $0.active.timeOfDay == "morning" }) { tod = "morning" }
            else { tod = "any" }
        }
        let todText = ["evening": "Вечером", "morning": "Утром", "any": "Утром или вечером"][tod!] ?? "Когда удобно"
        c.time = CardLine(text: [todText, layer(item.type)].compactMap { $0 }.joined(separator: ". ") + ".", source: plan?.timeOfDay != nil ? plan!.source : "kb",
                          confidence: plan?.timeOfDay != nil ? nil : strong.first?.active.evidence)

        // Как вводить
        if let plan {
            var t = "Начать: \(Catalog.frequency(plan.start).label.lowercased())"
            if let w = plan.stepUpWeeks, w > 0, plan.max != plan.start { t += ", повышать раз в \(w) нед. без раздражения до «\(Catalog.frequency(plan.max).label.lowercased())»" }
            c.intro = CardLine(text: t + "." + (plan.note.isEmpty ? "" : " \(plan.note)"), source: plan.source)
            c.scheduleKnown = true
        } else if item.isRetinoid {
            let (stages, weeks) = Retinoid.ladder(item, state)
            let mode = state.settings.cautious ? "осторожный режим" : "стандартный режим"
            let steps = stages.map { Catalog.frequency($0).label.lowercased() }.joined(separator: " → ")
            let rx = item.form.rx ? " Это рецептурная форма: частоту назначает врач, я только считаю дни." : ""
            c.intro = CardLine(text: "Общее правило (\(mode)): \(steps); шаг вверх — через \(weeks) нед. без покраснения, сухости и жжения.\(rx)", source: "kb", confidence: "high")
            c.scheduleKnown = false
        } else if let top = strong.filter({ $0.active.group != "retinoid" }).min(by: { (Knowledge.frequencyRank[$0.active.startFrequency] ?? 9) < (Knowledge.frequencyRank[$1.active.startFrequency] ?? 9) }) {
            let a = top.active
            let start = Catalog.frequencies[Knowledge.appFrequency(a.startFrequency) ?? ""]?.label.lowercased() ?? "по самочувствию"
            let maxF = a.maxFrequency == "2xdaily" ? "2 раз в день" : (Catalog.frequencies[a.maxFrequency]?.label.lowercased() ?? a.maxFrequency)
            let w = a.stepUpWeeks.map { " раз в \($0) нед." } ?? ""
            c.intro = CardLine(text: "Общее правило для «\(a.nameRu.lowercased())»: начать \(start), повышать\(w) без раздражения до «\(maxF)».", source: "kb", confidence: a.evidence)
            c.scheduleKnown = false
        } else {
            c.intro = CardLine(text: "Мягкое средство: можно каждый день, специального введения не нужно.", source: "kb")
            c.scheduleKnown = true
        }

        // С набором
        for other in state.items where !other.archived && other.id != item.id && !other.actives.contains("supplement") {
            let of = Knowledge.ingredients(of: other)
            var bad: (KB.Pair, Int)?
            var good: KB.Pair?
            var myth: KB.Pair?
            for a in found { for b in of {
                guard let p = Knowledge.pair(a.active, b.active) else { continue }
                if p.myth == true && (p.verdict == "ok" || p.verdict == "good_together") { myth = myth ?? p; continue }
                let r = Knowledge.verdictRank[p.verdict] ?? 1
                if r == 0 { good = good ?? p } else if r > 1, r > (bad?.1 ?? 1) { bad = (p, r) }
            } }
            if let p = bad?.0 ?? good { c.compat.append(CompatNote(otherId: other.id, otherName: other.name, verdict: p.verdict, why: p.why, confidence: p.confidence, condition: p.condition, myth: false)) }
            else if let p = myth { c.myths.append(CompatNote(otherId: other.id, otherName: other.name, verdict: p.verdict, why: p.why, confidence: p.confidence, condition: p.condition, myth: true)) }
        }
        c.compat.sort { (Knowledge.verdictRank[$0.verdict] ?? 0) > (Knowledge.verdictRank[$1.verdict] ?? 0) }

        // Кожа
        if state.settings.rosacea {
            var seen = Set<String>()
            for f in found {
                let key = f.active.id == "vitc_laa" ? "vitc_laa" : f.active.group
                if let t = Rosacea.notes[key], !seen.contains(key) { seen.insert(key); c.rosacea.append(t) }
            }
            c.triggers = Rosacea.triggers(in: item.composition)
        }
        c.sensitive = uniq(strong.map(\.active.sensitiveSkin).filter { !$0.isEmpty })

        // Безопасность
        if found.contains(where: { $0.active.spfRequired || $0.active.photosensitizing }) {
            c.safety.append(CardLine(text: "Утром обязательно SPF: кожа чувствительнее к солнцу.", source: "kb", confidence: "high"))
        }
        let preg = found.map(\.active.pregnancy)
        if preg.contains("avoid") {
            c.safety.append(CardLine(text: state.settings.pregnancy ? "Сейчас не использовать: при беременности и ГВ этот актив исключают." : "При беременности, её планировании и ГВ — не использовать.", source: "kb", confidence: "high"))
        } else if preg.contains("caution") {
            c.safety.append(CardLine(text: "При беременности и ГВ — только после разговора с врачом.", source: "kb", confidence: "medium"))
        }
        if item.isRetinoid && item.form.rx { c.safety.append(CardLine(text: "Рецептурное средство: схема и отмена — по назначению врача.", source: "kb", confidence: "high")) }

        c.expect = Array(uniq(strong.map(\.active.notes).filter { !$0.isEmpty }).prefix(3))
        var srcIds: [String] = []
        for f in strong.isEmpty ? found : strong { for s in f.active.sources where !srcIds.contains(s) { srcIds.append(s) } }
        c.sources = srcIds.prefix(6).compactMap(Knowledge.source)
        if state.settings.rosacea { c.sources.append(Rosacea.source) }
        return c
    }

    static func uniq(_ a: [String]) -> [String] { var seen = Set<String>(); return a.filter { seen.insert($0).inserted } }

    static func layer(_ type: String) -> String? {
        switch type {
        case "cleanser": return "Первым шагом, затем смыть"
        case "toner": return "После очищения"
        case "serum": return "После тоника, до крема"
        case "cream": return "После сывороток"
        case "spf": return "Последним утренним шагом, обновлять на солнце"
        case "oil": return "Последним шагом вечером"
        case "mask", "peel": return "На чистую сухую кожу, затем смыть"
        case "eye": return "Вокруг глаз, до крема"
        case "spot": return "Точечно, после крема или вместо него"
        default: return nil
        }
    }
}

// MARK: — розацеа

enum Rosacea {
    static let source = KB.Source(id: "dermnet-rosacea", title: "DermNet: Rosacea", url: "https://dermnetnz.org/topics/rosacea")

    static let notes: [String: String] = [
        "retinoid": "При розацеа ретиноиды вводят очень осторожно: редкий старт, «сэндвич» с кремом, лучше вместе с дерматологом — они могут усиливать покраснение.",
        "aha": "При розацеа AHA, особенно гликолевую, обычно не советуют. Если нужно отшелушивание — PHA или миндальная, редко.",
        "bha": "Салициловая при розацеа — только низкая концентрация и редко; при жжении — отменить.",
        "azelaic": "При розацеа азелаиновая кислота — одно из основных средств (15% гель — лекарство от розацеа). Покалывание в первые 1–2 недели бывает.",
        "vitc_laa": "L-аскорбиновая кислота при розацеа часто жжёт — мягче производные (SAP, аскорбил глюкозид).",
        "niacinamide": "Ниацинамид 2–5% при розацеа обычно хорошо переносится и укрепляет барьер; 10% и выше может давать покраснение.",
        "bpo": "Бензоилпероксид при розацеа часто раздражает — только по назначению врача.",
        "exfoliant_physical": "Скрабы и спикулы при розацеа не рекомендуют.",
        "enzyme": "Энзимы при розацеа — редко и коротко; при покраснении отменить.",
        "sulfur": "Сера при розацеа бывает полезна (есть лекарственные формы), но сушит.",
        "soothing": "Успокаивающие компоненты при розацеа — в плюс.",
        "barrier": "Барьерные компоненты (керамиды, липиды) при розацеа — в плюс.",
        "spf_filter": "При розацеа солнце — главный триггер: SPF каждый день, минеральные фильтры обычно переносятся лучше.",
    ]

    /// Частые раздражители кожи с розацеа.
    static let triggerWords: [(pattern: String, name: String)] = [
        (#"alcohol denat|sd alcohol|^alcohol$|ethanol"#, "спирт"), ("menthol", "ментол"), ("camphor", "камфора"),
        ("eucalyptus", "эвкалипт"), (#"mentha|peppermint"#, "мята"), (#"hamamelis|witch hazel"#, "гамамелис"),
        (#"^parfum$|^fragrance$"#, "отдушка"), ("sodium lauryl sulfate", "SLS"), (#"eugenia caryophyllus|clove"#, "гвоздика"), ("cinnamon", "корица"),
    ]

    static func triggers(in composition: String) -> [String] {
        var out: [String] = []
        for t in Knowledge.tokens(composition).map({ $0.lowercased() }) {
            for w in triggerWords where !out.contains(w.name) {
                if t.range(of: w.pattern, options: .regularExpression) != nil { out.append(w.name) }
            }
        }
        return out
    }
}

// MARK: — вкладыш

/// Разбор текста инструкции (OCR вкладыша) без ИИ: частота на старте, предел, шаг, время суток.
enum LeafletParser {
    private static let phrases: [(String, String)] = [
        (#"2\s*раза\s*в\s*день|два\s*раза\s*в\s*день|утром\s*и\s*вечером|twice\s*(a\s*)?da(il)?y|morning\s*and\s*evening"#, "daily"),
        (#"(1|один)\s*раз\s*в\s*неделю|раз\s*в\s*неделю|once\s*(a\s*)?week(ly)?"#, "1w"),
        (#"(2|два)\s*(-|–|или)?\s*(3)?\s*раза\s*в\s*неделю|twice\s*a\s*week|2\s*(-|–)?\s*3?\s*times\s*a\s*week"#, "2w"),
        (#"(3|три)\s*раза\s*в\s*неделю|(3|three)\s*times\s*a\s*week"#, "3w"),
        (#"через\s*(день|вечер|ночь)|кажд(ый|ую)\s*втор|every\s*other\s*(day|night|evening)|alternate\s*(days|nights)"#, "eod"),
        (#"ежедневно|каждый\s*(день|вечер)|кажд(ую|ой)\s*ноч|(1|один)\s*раз\s*в\s*день|every\s*(day|night|evening)|daily|nightly|once\s*a\s*day"#, "daily"),
    ]

    static func parse(_ text: String) -> IntroPlan? {
        let lower = text.lowercased()
        var hits: [(pos: Int, freq: String)] = []
        var taken: [Range<String.Index>] = []
        for (p, f) in phrases {
            var from = lower.startIndex
            while let r = lower.range(of: p, options: .regularExpression, range: from..<lower.endIndex) {
                if !taken.contains(where: { $0.overlaps(r) }) { hits.append((lower.distance(from: lower.startIndex, to: r.lowerBound), f)); taken.append(r) }
                from = r.upperBound
            }
        }
        guard let first = hits.min(by: { $0.pos < $1.pos }) else { return nil }
        let rank = { (f: String) in Knowledge.frequencyRank[f] ?? 0 }
        let maxF = hits.map(\.freq).max { rank($0) < rank($1) } ?? first.freq
        var plan = IntroPlan(source: "leaflet", start: first.freq, stepUpWeeks: nil, max: rank(maxF) > rank(first.freq) ? maxF : first.freq)
        if let r = lower.range(of: #"(\d+)\s*(-|–)?\s*\d*\s*(недел|week)"#, options: .regularExpression),
           let n = Int(lower[r].prefix { $0.isNumber }) , n > 0, n <= 12 { plan.stepUpWeeks = n }
        else if plan.max != plan.start { plan.stepUpWeeks = 2 }
        let evening = lower.range(of: #"вечер|на ночь|перед сном|evening|night|\bpm\b"#, options: .regularExpression) != nil
        let morning = lower.range(of: #"утр|morning|\bam\b"#, options: .regularExpression) != nil
        plan.timeOfDay = evening && morning ? "any" : evening ? "evening" : morning ? "morning" : nil
        // Цитата — предложение с первой найденной частотой.
        let idx = lower.index(lower.startIndex, offsetBy: first.pos)
        let start = lower[..<idx].lastIndex(where: { ".!\n".contains($0) }).map { lower.index(after: $0) } ?? lower.startIndex
        let end = lower[idx...].firstIndex(where: { ".!\n".contains($0) }) ?? lower.endIndex
        let s = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: start))
        let e = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: end))
        plan.quote = String(text[s..<e]).trimmingCharacters(in: .whitespacesAndNewlines).prefix(240).description
        return plan
    }
}
