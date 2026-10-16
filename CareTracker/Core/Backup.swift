import Foundation

// Импорт и экспорт копии — тот же JSON, что у PWA. Фото лица идут отдельным массивом.

struct BackupPhoto: Codable, Equatable { let id: String; let day: String; let at: String?; let data: String }

enum BackupError: LocalizedError, Equatable {
    case notJson, notOurs, tooNew
    var errorDescription: String? {
        switch self {
        case .notJson: return "Файл повреждён или это не JSON."
        case .notOurs: return "Это не файл копии «Ритма кожи»: в нём нет списка средств или отметок."
        case .tooNew: return "Копия сделана более новой версией приложения. Обнови приложение и попробуй снова."
        }
    }
}

enum Backup {
    static func decode(_ data: Data) throws -> (state: AppState, photos: [BackupPhoto]) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw BackupError.notJson }
        guard obj["items"] is [Any], obj["entries"] is [Any] else { throw BackupError.notOurs }
        if let v = obj["version"] as? Int, v > AppState.schemaVersion { throw BackupError.tooNew }
        let dec = JSONDecoder()
        let state: AppState
        do { state = try dec.decode(AppState.self, from: data) } catch { throw BackupError.notOurs }
        struct P: Decodable { var photos: [BackupPhoto]? }
        let photos = (try? dec.decode(P.self, from: data).photos) ?? nil
        return (migrate(state), photos ?? [])
    }

    static func migrate(_ input: AppState) -> AppState {
        var s = input
        for i in s.items.indices {
            var it = s.items[i]
            if it.type.isEmpty {
                let n = it.name.lowercased()
                it.type = it.actives.contains("supplement") ? "supplement" : it.actives.contains("spf") ? "spf" : n.contains("крем") ? "cream" : n.contains("сыворотк") ? "serum" : n.contains("патч") ? "eye" : "other"
            }
            if it.isRetinoid && it.retinoidForm == nil { it.retinoidForm = (it.name.lowercased().contains("ретинал") || it.name.lowercased().contains("retinal")) ? "retinal" : "retinol" }
            if it.isRetinoid && it.schedule.type != "interval" && it.block != "optional" { it.schedule.type = "interval"; it.schedule.freq = it.schedule.freq ?? it.form.start }
            s.items[i] = it
        }
        if s.version < 2 { s.rules["retinoid-acids-adjacent"] = false }
        s.version = AppState.schemaVersion
        return s
    }

    static func encode(_ state: AppState, photos: [BackupPhoto] = [], exportedAt: Date = Date()) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        var obj = try JSONSerialization.jsonObject(with: enc.encode(state)) as! [String: Any]
        obj["app"] = "ritm-kozhi"
        obj["exportedAt"] = ISO8601DateFormatter().string(from: exportedAt)
        if !photos.isEmpty { obj["photos"] = try JSONSerialization.jsonObject(with: enc.encode(photos)) }
        return try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
    }
}
