import Foundation

// Поиск активов в тексте состава (INCI) — работает офлайн, без ИИ.

struct InciMatch: Equatable { let active: String; let range: Range<String.Index> }

enum Inci {
    static let dictionary: [(String, [String])] = [
        ("retinoid", ["retinal", "retinaldehyde", "retinol", "retinyl", "tretinoin", "adapalene", "hydroxypinacolone retinoate", "granactive retinoid", "ретиналь", "ретинол", "ретиноид"]),
        ("aha", ["glycolic", "lactic acid", "mandelic", "malic acid", "tartaric", "гликолев", "молочн", "миндальн"]),
        ("bha", ["salicylic", "betaine salicylate", "willow bark", "салицил"]),
        ("pha", ["gluconolactone", "lactobionic", "глюконолактон"]),
        ("azelaic", ["azelaic", "potassium azeloyl", "азелаин"]),
        ("niacinamide", ["niacinamide", "nicotinamide", "ниацинамид"]),
        ("vitc", ["ascorbic", "ascorbyl", "ethyl ascorbic", "аскорбин"]),
        ("copper", ["copper tripeptide", "ghk-cu", "медные пептиды"]),
        ("peptides", ["peptide", "palmitoyl", "acetyl hexapeptide", "argireline", "matrixyl", "пептид"]),
        ("exfoliant", ["papain", "bromelain", "subtilisin", "папаин", "бромелайн"]),
        ("bpo", ["benzoyl peroxide", "бензоилпероксид"]),
        ("spf", ["spf", "zinc oxide", "titanium dioxide", "avobenzone", "octocrylene", "tinosorb", "uvinul", "ethylhexyl methoxycinnamate", "homosalate"]),
    ]

    /// Активы в порядке словаря и найденные фрагменты (для подсветки).
    static func detect(_ text: String) -> (actives: [String], matches: [InciMatch]) {
        let low = text.lowercased()
        var found: [String] = []
        var matches: [InciMatch] = []
        for (active, words) in dictionary {
            for w in words {
                var start = low.startIndex
                while let r = low.range(of: w, range: start..<low.endIndex) {
                    if !found.contains(active) { found.append(active) }
                    // индексы lowercased() совпадают по смещению для латиницы и кириллицы
                    let lo = text.index(text.startIndex, offsetBy: low.distance(from: low.startIndex, to: r.lowerBound), limitedBy: text.endIndex) ?? text.endIndex
                    let hi = text.index(lo, offsetBy: low.distance(from: r.lowerBound, to: r.upperBound), limitedBy: text.endIndex) ?? text.endIndex
                    matches.append(InciMatch(active: active, range: lo..<hi))
                    start = r.upperBound
                }
            }
        }
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        return (found, matches)
    }

    /// Угадать форму ретиноида по составу.
    static func retinoidForm(_ text: String) -> String? {
        let low = text.lowercased()
        if low.contains("tretinoin") { return "tretinoin" }
        if low.contains("tazarotene") { return "tazarotene" }
        if low.contains("adapalene") { return "adapalene" }
        if low.contains("retinal") || low.contains("ретиналь") { return "retinal" }
        if low.contains("hydroxypinacolone") || low.contains("granactive") { return "hpr" }
        if low.contains("retinyl") { return "retinyl_esters" }
        if low.contains("retinol") || low.contains("ретинол") { return "retinol" }
        return nil
    }
}
