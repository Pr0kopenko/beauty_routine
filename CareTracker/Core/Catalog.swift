import Foundation

// Справочники: активы, типы средств, этапы и формы ретиноидов, правила, реакции.
// Источники и уровень доказательности — в ТЗ (Claude Docs), раздел «v2 — для друзей».

struct Active: Equatable { let id: String; let name: String; let color: String }
struct Frequency: Equatable { let id: String; let label: String; let short: String; let minDays: Int; let maxPerWeek: Int }
struct RetinoidForm: Equatable { let id: String; let name: String; let strength: Int; let start: String; let weeks: Int; let rx: Bool }
struct Rule: Equatable { let id: String; let text: String; let sub: String; let confidence: String; let source: String?; let defaultOn: Bool }

enum Catalog {
    static let actives: [Active] = [
        Active(id: "retinoid", name: "Ретиноид", color: "ret"),
        Active(id: "aha", name: "AHA", color: "acid"),
        Active(id: "bha", name: "BHA", color: "acid"),
        Active(id: "pha", name: "PHA", color: "acid"),
        Active(id: "azelaic", name: "Азелаиновая кислота", color: "az"),
        Active(id: "niacinamide", name: "Ниацинамид", color: "ni"),
        Active(id: "vitc", name: "Витамин C", color: "vc"),
        Active(id: "peptides", name: "Пептиды", color: "pep"),
        Active(id: "copper", name: "Медные пептиды", color: "pep"),
        Active(id: "exfoliant", name: "Скраб или энзимы", color: "acid"),
        Active(id: "bpo", name: "Бензоилпероксид", color: "acid"),
        Active(id: "spf", name: "SPF", color: "spf"),
        Active(id: "supplement", name: "Добавка", color: "sup"),
    ]
    static func activeName(_ id: String) -> String { actives.first { $0.id == id }?.name ?? id }
    static let acidGroup: Set<String> = ["aha", "bha", "pha"] // азелаиновая сюда не входит
    /// Активы, которые ставятся на паузу при раздражении кожи (DermNet: пауза во всех активах).
    static let strongActives: Set<String> = ["retinoid", "aha", "bha", "pha", "azelaic", "vitc", "bpo", "exfoliant"]

    static let productTypes: [(id: String, name: String)] = [
        ("cleanser", "Очищение"), ("toner", "Тоник"), ("serum", "Сыворотка"), ("cream", "Крем"), ("spf", "SPF"),
        ("mask", "Маска"), ("peel", "Пилинг"), ("eye", "Для глаз"), ("oil", "Масло"), ("spot", "Точечное"),
        ("supplement", "Добавка"), ("other", "Другое"),
    ]
    static func typeName(_ id: String) -> String { productTypes.first { $0.id == id }?.name ?? "Другое" }

    static let blocks: [(id: String, name: String)] = [("morning", "Утро"), ("evening", "Вечер"), ("supplements", "Добавки"), ("optional", "По желанию")]

    // Этапы введения ретиноида (эвристика приложения).
    static let frequencies: [String: Frequency] = [
        "1w": Frequency(id: "1w", label: "1 раз в неделю", short: "1×/нед", minDays: 7, maxPerWeek: 1),
        "2w": Frequency(id: "2w", label: "2 раза в неделю", short: "2×/нед", minDays: 3, maxPerWeek: 2),
        "3w": Frequency(id: "3w", label: "3 раза в неделю", short: "3×/нед", minDays: 2, maxPerWeek: 3),
        "eod": Frequency(id: "eod", label: "Через день", short: "через день", minDays: 2, maxPerWeek: 4),
        "5w": Frequency(id: "5w", label: "4–5 раз в неделю", short: "4–5×/нед", minDays: 1, maxPerWeek: 5),
        "daily": Frequency(id: "daily", label: "Каждый вечер", short: "каждый вечер", minDays: 1, maxPerWeek: 7),
    ]
    /// Осторожная лестница (чувствительная кожа, розацеа, первый ретиноид): 8–12 недель до ежедневного.
    static let stageOrder = ["1w", "2w", "eod", "5w", "daily"]
    /// Стандартная лестница, как у большинства брендов (Medik8, LRP, COSRX): ~4–5 недель до ежедневного.
    static let standardOrder = ["2w", "eod", "daily"]
    /// Все частоты по возрастанию — для ручной схемы.
    static let allFrequencies = ["1w", "2w", "3w", "eod", "5w", "daily"]
    static func frequency(_ id: String?) -> Frequency { frequencies[id ?? "2w"] ?? frequencies["2w"]! }

    static let retinoidForms: [String: RetinoidForm] = [
        "retinyl_esters": RetinoidForm(id: "retinyl_esters", name: "Ретиниловые эфиры", strength: 1, start: "eod", weeks: 1, rx: false),
        "hpr": RetinoidForm(id: "hpr", name: "HPR (гидроксипинаколон ретиноат)", strength: 2, start: "eod", weeks: 2, rx: false),
        "retinol": RetinoidForm(id: "retinol", name: "Ретинол", strength: 2, start: "2w", weeks: 2, rx: false),
        "retinal": RetinoidForm(id: "retinal", name: "Ретиналь", strength: 3, start: "2w", weeks: 2, rx: false),
        "adapalene": RetinoidForm(id: "adapalene", name: "Адапален", strength: 3, start: "eod", weeks: 2, rx: false),
        "tretinoin": RetinoidForm(id: "tretinoin", name: "Третиноин", strength: 5, start: "2w", weeks: 3, rx: true),
        "tazarotene": RetinoidForm(id: "tazarotene", name: "Тазаротен", strength: 5, start: "2w", weeks: 4, rx: true),
    ]
    static let retinoidFormOrder = ["retinyl_esters", "hpr", "retinol", "retinal", "adapalene", "tretinoin", "tazarotene"]

    private static let aadExf = "https://www.aad.org/public/everyday-care/skin-care-secrets/routine/safely-exfoliate-at-home"
    private static let aadRet = "https://www.aad.org/public/everyday-care/skin-care-secrets/anti-aging/retinoid-retinol"
    static let rules: [Rule] = [
        Rule(id: "retinoid-interval", text: "Ретиноид — по графику введения", sub: "интервал и число раз в неделю по этапу", confidence: "эвристика", source: nil, defaultOn: true),
        Rule(id: "retinoid-evening", text: "Ретиноид — только вечером", sub: "разрушается на свету", confidence: "высокий", source: aadRet, defaultOn: true),
        Rule(id: "retinoid-acids", text: "Ретиноид и AHA/BHA/PHA — разные вечера", sub: "вместе сильнее сушит; в соседние дни можно", confidence: "средний", source: aadExf, defaultOn: true),
        Rule(id: "retinoid-azelaic", text: "Ретиноид и азелаиновая — разные вечера", sub: "перестраховка на время введения; по исследованиям сочетаются", confidence: "низкий", source: "https://pubmed.ncbi.nlm.nih.gov/17014483/", defaultOn: true),
        Rule(id: "retinoid-bpo", text: "Ретинол/ретиналь/третиноин и бензоилпероксид — в разное время суток", sub: "БПО окисляет ретиноиды; адапален устойчив", confidence: "высокий", source: "https://pubmed.ncbi.nlm.nih.gov/9990414/", defaultOn: true),
        Rule(id: "vitc-retinoid", text: "Витамин C — утром, ретиноид — вечером", sub: "", confidence: "низкий", source: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5605218/", defaultOn: true),
        Rule(id: "vitc-acids", text: "Витамин C и кислоты — в разное время суток", sub: "оба кислотные, вместе больше раздражения", confidence: "низкий", source: nil, defaultOn: true),
        Rule(id: "vitc-bpo", text: "Витамин C и бензоилпероксид — в разное время суток", sub: "БПО окисляет витамин C", confidence: "средний", source: "https://www.dermatologytimes.com/view/facial-care-advice-patients-acne", defaultOn: true),
        Rule(id: "bpo-acids", text: "Бензоилпероксид и кислоты — разные дни", sub: "", confidence: "средний", source: "https://dermnetnz.org/topics/salicylic-acid", defaultOn: true),
        Rule(id: "one-exfoliant", text: "Один эксфолиант за день", sub: "кислоты, скраб, энзимы, пилинг-маска — в разные дни", confidence: "средний", source: aadExf, defaultOn: true),
        Rule(id: "copper-acids", text: "Медные пептиды отдельно от кислот и витамина C", sub: "при низком pH комплекс меди может распадаться", confidence: "низкий", source: "https://pmc.ncbi.nlm.nih.gov/articles/PMC6073405/", defaultOn: true),
        Rule(id: "acids-weekly", text: "Кислоты AHA/BHA — до 2–3 раз в неделю", sub: "подсказка с третьего раза за 7 дней", confidence: "эвристика", source: nil, defaultOn: true),
        Rule(id: "irritation-load", text: "Не больше активов за один приём, чем выдержит кожа", sub: "сумма сил активов с учётом концентрации; при розацеа и чувствительной коже лимит ниже", confidence: "эвристика", source: nil, defaultOn: true),
        Rule(id: "retinoid-acids-adjacent", text: "Ретиноид и кислоты — не в соседние вечера", sub: "строже, чем нужно по данным; для чувствительной кожи", confidence: "низкий", source: nil, defaultOn: false),
        Rule(id: "spf-after", text: "SPF утром после ретиноида или кислот", sub: "выделю SPF на утро", confidence: "высокий", source: "https://www.fda.gov/cosmetics/cosmetic-ingredients/alpha-hydroxy-acids", defaultOn: true),
    ]
    static func rule(_ id: String) -> Rule? { rules.first { $0.id == id } }

    static let reactions: [(id: String, name: String)] = [("redness", "Покраснение"), ("dryness", "Сухость, шелушение"), ("burning", "Жжение, пощипывание"), ("breakouts", "Высыпания")]
    static let levels = ["нет", "слабо", "средне", "сильно"]
}
