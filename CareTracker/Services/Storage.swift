import Foundation

/// Состояние приложения — один JSON-файл в Application Support (формат как у копии PWA).
/// Защита файла: доступен после первой разблокировки, чтобы «Сделала» из уведомления работало на заблокированном экране.
enum Storage {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Ritm", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static var stateURL: URL { directory.appendingPathComponent("state.json") }

    static func load() -> AppState {
        guard let data = try? Data(contentsOf: stateURL) else { return AppState() }
        if let (state, _) = try? Backup.decode(data) { return state }
        return AppState()
    }

    static func save(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("Не получилось сохранить состояние: \(error)")
        }
    }
}
