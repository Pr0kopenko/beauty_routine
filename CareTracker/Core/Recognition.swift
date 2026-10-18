import Foundation

// Результат распознавания средства (ИИ или офлайн) и разбор ответа ИИ.

struct RecognizedProduct: Equatable {
    enum Source: String { case ai, device }
    var isSkincare = true
    var brand = ""
    var name = ""
    var type = "other"
    var actives: [String] = []
    var retinoidForm: String? = nil
    var strength = ""
    /// morning · evening · any
    var time = "any"
    var composition = ""
    var confidence = "medium"
    var note = ""
    var source: Source = .ai
    /// Схема введения, если она видна на фото или модель знает инструкцию производителя.
    var intro: IntroPlan? = nil

    var displayName: String {
        let n = name.trimmingCharacters(in: .whitespaces), b = brand.trimmingCharacters(in: .whitespaces)
        if !b.isEmpty && !n.lowercased().contains(b.lowercased()) { return n.isEmpty ? b : "\(b) \(n)" }
        return n.isEmpty ? b : n
    }
    var suggestedBlock: String {
        if actives.contains("supplement") || type == "supplement" { return "supplements" }
        if type == "spf" || time == "morning" { return "morning" }
        if actives.contains("retinoid") || time == "evening" { return "evening" }
        return "optional"
    }
}

enum Recognition {
    static let activeIds = Catalog.actives.map(\.id)

    static var schema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "is_skincare": ["type": "boolean"],
                "brand": ["type": "string"],
                "name": ["type": "string"],
                "product_type": ["type": "string", "enum": Catalog.productTypes.map(\.id)],
                "actives": ["type": "array", "items": ["type": "string", "enum": activeIds]],
                "retinoid_form": ["type": "string", "enum": ["none"] + Catalog.retinoidFormOrder],
                "strength": ["type": "string"],
                "time_of_day": ["type": "string", "enum": ["morning", "evening", "any"]],
                "inci_text": ["type": "string"],
                "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
                "note_ru": ["type": "string"],
                "intro_source": ["type": "string", "enum": ["photo_text", "manufacturer_known", "none"]],
                "intro_start": ["type": "string", "enum": Catalog.allFrequencies + ["none"]],
                "intro_step_weeks": ["type": "integer"],
                "intro_max": ["type": "string", "enum": Catalog.allFrequencies + ["none"]],
                "intro_quote": ["type": "string"],
            ],
            "required": ["is_skincare", "brand", "name", "product_type", "actives", "retinoid_form", "strength", "time_of_day", "inci_text", "confidence", "note_ru",
                         "intro_source", "intro_start", "intro_step_weeks", "intro_max", "intro_quote"],
            "additionalProperties": false,
        ]
    }

    static var prompt: String {
        """
        Ты помогаешь вести трекер ухода за кожей. На фото — косметическое средство или БАД (упаковка, флакон или состав на обороте).
        Определи:
        - brand, name — бренд и название как на упаковке. Если не видно — лучшая догадка, и confidence "low".
        - product_type — один из: \(Catalog.productTypes.map { "\($0.id) (\($0.name))" }.joined(separator: ", ")).
        - actives — активные компоненты из списка: \(Catalog.actives.map { "\($0.id) (\($0.name))" }.joined(separator: ", ")). Бери из видимого состава (INCI) или заявленного на упаковке; если состав не виден — из того, что знаешь об этом продукте. Не добавляй то, в чём не уверена. «Citric acid» в конце состава — регулятор pH, не AHA.
        - retinoid_form — если есть ретиноид: retinyl_esters, retinol, retinal, hpr, adapalene, tretinoin, tazarotene (бакучиол — не ретиноид). Иначе "none".
        - strength — концентрация главного актива, если указана, иначе "".
        - time_of_day — morning для SPF, evening для ретиноидов и сильных кислот, иначе any.
        - inci_text — состав, если читается на фото, иначе "".
        - note_ru — одно короткое предложение по-русски: что это и как обычно используют.
        - intro_* — схема введения ИМЕННО этого продукта: photo_text, если инструкция видна на фото (тогда intro_quote — дословная цитата); manufacturer_known, только если ты уверенно знаешь официальную инструкцию производителя (intro_quote — её суть); иначе none. Частоты: 1w (раз в неделю), 2w, 3w, eod (через день), 5w, daily. intro_step_weeks — через сколько недель повышать (0, если не сказано). Не выдумывай схему.
        Если на фото не уход и не БАД — is_skincare=false.
        """
    }

    /// Разбор JSON-ответа ИИ (строгого или «грязного» текста с JSON внутри).
    static func parse(_ text: String) -> RecognizedProduct? {
        var json = text
        if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") { json = String(text[s...e]) }
        guard let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] else { return nil }
        var r = RecognizedProduct()
        r.isSkincare = obj["is_skincare"] as? Bool ?? true
        r.brand = (obj["brand"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        r.name = (obj["name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let type = obj["product_type"] as? String ?? "other"
        r.type = Catalog.productTypes.contains { $0.id == type } ? type : "other"
        var actives = (obj["actives"] as? [String] ?? []).filter { activeIds.contains($0) }
        let form = obj["retinoid_form"] as? String
        let validForm = form.flatMap { Catalog.retinoidForms[$0] != nil ? $0 : nil }
        if validForm != nil && !actives.contains("retinoid") { actives.insert("retinoid", at: 0) }
        r.actives = actives
        r.retinoidForm = actives.contains("retinoid") ? (validForm ?? "retinol") : nil
        r.strength = obj["strength"] as? String ?? ""
        let t = obj["time_of_day"] as? String ?? "any"
        r.time = ["morning", "evening"].contains(t) ? t : "any"
        r.composition = obj["inci_text"] as? String ?? ""
        r.confidence = obj["confidence"] as? String ?? "medium"
        r.note = obj["note_ru"] as? String ?? ""
        r.source = .ai
        let src = obj["intro_source"] as? String ?? "none"
        let start = obj["intro_start"] as? String ?? "none"
        if src != "none", Catalog.frequencies[start] != nil {
            let maxF = obj["intro_max"] as? String ?? start
            let weeks = obj["intro_step_weeks"] as? Int ?? 0
            r.intro = IntroPlan(source: src == "photo_text" ? "leaflet" : "ai", start: start, stepUpWeeks: weeks > 0 ? weeks : nil,
                                max: Catalog.frequencies[maxF] != nil ? maxF : start, timeOfDay: r.time == "any" ? nil : r.time,
                                note: "", quote: (obj["intro_quote"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        }
        return r
    }
}
