import UIKit

/// Распознавание средства по фото через Claude или ChatGPT.
/// Режимы: свой ключ (Keychain) или сервер-посредник с инвайт-кодом (см. proxy/worker.js).
struct AISettings: Codable, Equatable {
    var provider = "claude"            // claude · openai · proxy
    var model = "claude-haiku-5-5"
    var proxyURL = ""
    static let defaultsKey = "ai.settings"

    static func load() -> AISettings {
        guard let d = UserDefaults.standard.data(forKey: defaultsKey), let s = try? JSONDecoder().decode(AISettings.self, from: d) else { return AISettings() }
        return s
    }
    func save() { if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: AISettings.defaultsKey) } }

    /// Ключ API или инвайт-код посредника — в Keychain.
    var secret: String { Keychain.get(provider) }
    var isReady: Bool { provider == "proxy" ? (!proxyURL.isEmpty && !secret.isEmpty) : !secret.isEmpty }
    /// Адрес сервера без хвостового «/» и без пути модели.
    var proxyBase: String {
        var u = proxyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while u.hasSuffix("/") { u.removeLast() }
        for suffix in ["/openai", "/anthropic"] where u.hasSuffix(suffix) { u.removeLast(suffix.count) }
        return u
    }
}

enum AIError: LocalizedError {
    case noKey, network, auth, billing, rate, model(String), server, refusal, parse, other(String)
    var errorDescription: String? {
        switch self {
        case .noKey: return "Распознавание пока не подключено."
        case .network: return "Нет связи с сервисом ИИ. Проверь интернет и попробуй ещё раз."
        case .auth: return "Ключ не подошёл. Проверь, что он скопирован целиком."
        case .billing: return "На счёте ИИ закончились деньги или лимит."
        case .rate: return "Слишком много запросов. Подожди минуту и попробуй снова."
        case .model(let m): return "Модель недоступна для этого ключа (\(m)). Выбери другую в настройках."
        case .server: return "Сервис ИИ перегружен. Попробуй через минуту."
        case .refusal: return "ИИ отказался разбирать это фото. Попробуй другое или заполни вручную."
        case .parse: return "Не разобрала ответ ИИ. Попробуй ещё раз."
        case .other(let m): return "Ошибка ИИ: \(m)"
        }
    }
}

enum AIClient {
    static func recognize(_ image: UIImage, settings: AISettings = .load()) async throws -> RecognizedProduct {
        guard settings.isReady else { throw AIError.noKey }
        let jpeg = image.resized(maxSide: 1280).jpegData(compressionQuality: 0.85) ?? Data()
        let b64 = jpeg.base64EncodedString()
        let text: String
        switch settings.provider {
        case "openai": text = try await openAI(settings, b64, url: "https://api.openai.com/v1/responses", auth: ["authorization": "Bearer \(settings.secret)"])
        case "proxy" where settings.model.hasPrefix("gpt"):
            text = try await openAI(settings, b64, url: settings.proxyBase + "/openai", auth: ["x-invite": settings.secret])
        case "proxy": text = try await claude(settings, b64, url: settings.proxyBase + "/anthropic", auth: ["x-invite": settings.secret])
        default: text = try await claude(settings, b64, url: "https://api.anthropic.com/v1/messages", auth: ["x-api-key": settings.secret])
        }
        guard let r = Recognition.parse(text) else { throw AIError.parse }
        return r
    }

    static func test(_ settings: AISettings) async throws {
        switch settings.provider {
        case "openai": _ = try await post("https://api.openai.com/v1/responses", ["authorization": "Bearer \(settings.secret)"], ["model": settings.model, "input": "Ответь одним словом: ок", "max_output_tokens": 16])
        case "proxy" where settings.model.hasPrefix("gpt"):
            _ = try await post(settings.proxyBase + "/openai", ["x-invite": settings.secret], ["model": settings.model, "input": "Ответь одним словом: ок", "max_output_tokens": 16])
        case "proxy": _ = try await post(settings.proxyBase + "/anthropic", ["x-invite": settings.secret, "anthropic-version": "2023-06-01"], ["model": settings.model, "max_tokens": 16, "messages": [["role": "user", "content": "Ответь одним словом: ок"]]])
        default: _ = try await post("https://api.anthropic.com/v1/messages", ["x-api-key": settings.secret, "anthropic-version": "2023-06-01"], ["model": settings.model, "max_tokens": 16, "messages": [["role": "user", "content": "Ответь одним словом: ок"]]])
        }
    }

    private static func claude(_ s: AISettings, _ b64: String, url: String, auth: [String: String]) async throws -> String {
        let body: [String: Any] = [
            "model": s.model, "max_tokens": 1500,
            "output_config": ["format": ["type": "json_schema", "schema": Recognition.schema]],
            "messages": [["role": "user", "content": [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": b64]],
                ["type": "text", "text": Recognition.prompt],
            ]]],
        ]
        var headers = auth; headers["anthropic-version"] = "2023-06-01"
        let msg = try await post(url, headers, body)
        if msg["stop_reason"] as? String == "refusal" { throw AIError.refusal }
        let content = msg["content"] as? [[String: Any]] ?? []
        return content.first { $0["type"] as? String == "text" }?["text"] as? String ?? ""
    }

    private static func openAI(_ s: AISettings, _ b64: String, url: String, auth: [String: String]) async throws -> String {
        let body: [String: Any] = [
            "model": s.model,
            "input": [["role": "user", "content": [
                ["type": "input_text", "text": Recognition.prompt],
                ["type": "input_image", "image_url": "data:image/jpeg;base64,\(b64)", "detail": "high"],
            ]]],
            "text": ["format": ["type": "json_schema", "name": "product", "strict": true, "schema": Recognition.schema]],
        ]
        let r = try await post(url, auth, body)
        if let t = r["output_text"] as? String { return t }
        let outputs = r["output"] as? [[String: Any]] ?? []
        for o in outputs { for c in o["content"] as? [[String: Any]] ?? [] where c["type"] as? String == "output_text" { return c["text"] as? String ?? "" } }
        return ""
    }

    private static func post(_ url: String, _ headers: [String: String], _ body: [String: Any]) async throws -> [String: Any] {
        guard let u = URL(string: url) else { throw AIError.other("неверный адрес") }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw AIError.network }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let m = (obj["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(status)"
            switch status {
            case 401: throw AIError.auth
            case 402: throw AIError.billing
            case 429: throw AIError.rate
            case 404: throw AIError.model(m)
            case 500...: throw AIError.server
            default: throw m.lowercased().contains("credit") || m.lowercased().contains("billing") ? AIError.billing : AIError.other(m)
            }
        }
        return obj
    }
}
