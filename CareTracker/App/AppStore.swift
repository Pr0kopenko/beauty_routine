import SwiftUI
import Observation

enum Tab: Hashable { case today, skin, products, history }

struct Toast: Equatable, Identifiable {
    let id = Ids.make()
    let text: String
    var undo: (() -> Void)? = nil
    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

/// Отметка, которую нужно подтвердить: есть подсказки совместимости.
struct PendingMark: Identifiable {
    let id = Ids.make()
    let itemId: String
    let day: String
    let slot: String
    let hints: [Hint]
}

/// Единственный источник правды для UI. Любое изменение состояния сохраняется на диск
/// и перестраивает уведомления.
@Observable @MainActor
final class AppStore {
    var state: AppState
    var route: Tab = .today
    var today: String = Days.key()
    var toast: Toast?
    var pending: PendingMark?
    var showSettings = false

    init(state: AppState = Storage.load()) {
        self.state = state
    }

    // MARK: — сохранение

    private func commit(_ change: (inout AppState) -> Void) {
        change(&state)
        Storage.save(state)
        Notifications.shared.reschedule(state)
    }

    func refreshDay() {
        let d = Days.key()
        if d != today { today = d }
        Notifications.shared.reschedule(state)
    }

    var plan: DayPlan { Planner.plan(state, day: today) }
    var activeItems: [Item] { state.items.filter { !$0.archived } }

    func show(_ text: String, undo: (() -> Void)? = nil) {
        toast = Toast(text: text, undo: undo)
    }

    // MARK: — отметки

    /// Отметить средство. Если есть подсказки — сначала показываем их (отметку можно сделать всё равно).
    func requestMark(_ itemId: String, day: String? = nil, slot: String? = nil) {
        guard let item = state.item(itemId) else { return }
        let d = day ?? today
        let s = slot ?? Planner.defaultSlot(item, hour: Days.calendar.component(.hour, from: Date()))
        let hints = Compatibility.check(itemId: itemId, day: d, slot: s, in: state)
        if hints.isEmpty { mark(itemId, day: d, slot: s) } else { pending = PendingMark(itemId: itemId, day: d, slot: s, hints: hints) }
    }

    func mark(_ itemId: String, day: String, slot: String, overrode: Bool = false) {
        let e = Actions.entry(itemId: itemId, day: day, slot: slot, overrode: overrode)
        commit { $0.entries.append(e) }
        let name = state.item(itemId)?.name ?? "Средство"
        show("\(name) — отмечено") { [weak self] in self?.removeEntries([e.id]) }
    }

    func confirmPending() {
        guard let p = pending else { return }
        pending = nil
        mark(p.itemId, day: p.day, slot: p.slot, overrode: true)
    }

    func removeEntries(_ ids: [String]) {
        commit { s in s.entries.removeAll { ids.contains($0.id) } }
    }

    /// Нажатие на строку «Сегодня»: отметить или снять отметку.
    func toggle(_ itemId: String) {
        let existing = state.entries.filter { $0.itemId == itemId && $0.day == today && !$0.skipped }
        if existing.isEmpty { requestMark(itemId); return }
        removeEntries(existing.map(\.id))
        show("Отметка снята") { [weak self] in self?.commit { $0.entries.append(contentsOf: existing) } }
    }

    func markBlock(kind: String, day: String) {
        var added: [Entry] = []
        commit { added = Actions.markBlock(&$0, kind: kind, day: day) }
        if !added.isEmpty {
            let ids = added.map(\.id)
            show("Отмечено: \(added.count)") { [weak self] in self?.removeEntries(ids) }
        }
    }

    func skipBlock(kind: String, day: String) {
        commit { Actions.skipBlock(&$0, kind: kind, day: day) }
    }

    func moveEntry(_ id: String, to day: String, slot: String) {
        commit { s in
            guard let i = s.entries.firstIndex(where: { $0.id == id }) else { return }
            s.entries[i].day = day; s.entries[i].slot = slot; s.entries[i].time = nil
        }
    }

    // MARK: — средства

    @discardableResult
    func addItem(_ r: RecognizedProduct, block: String? = nil, image: UIImage? = nil) -> Item {
        let thumb = image.flatMap { PhotoStore.saveThumb($0) }
        let it = Actions.makeItem(r, block: block, thumb: thumb, today: today)
        commit { $0.items.append(it) }
        return it
    }

    func update(_ item: Item) {
        commit { s in if let i = s.items.firstIndex(where: { $0.id == item.id }) { s.items[i] = item } }
    }

    func setThumb(_ itemId: String, image: UIImage) {
        guard let name = PhotoStore.saveThumb(image) else { return }
        commit { s in if let i = s.items.firstIndex(where: { $0.id == itemId }) { s.items[i].thumb = name } }
    }

    func archive(_ itemId: String, _ value: Bool = true) {
        commit { s in if let i = s.items.firstIndex(where: { $0.id == itemId }) { s.items[i].archived = value } }
    }

    /// Удаление средства вместе с отметками (история ретиноида пересчитается).
    func delete(_ itemId: String) {
        commit { s in
            s.items.removeAll { $0.id == itemId }
            s.entries.removeAll { $0.itemId == itemId }
        }
    }

    func applyFrequency(_ itemId: String, _ freq: String) {
        commit { Actions.applyFrequency(&$0, itemId: itemId, freq: freq, today: today) }
        show("Частота: \(Catalog.frequency(freq).label.lowercased())")
    }

    func snoozeAdvice(_ itemId: String, days: Int = 7) {
        commit { s in if let i = s.items.firstIndex(where: { $0.id == itemId }) { s.items[i].schedule.snoozeUntil = Days.add(today, days) } }
    }

    // MARK: — дневник кожи

    func diary(_ day: String) -> DiaryDay { state.diary[day] ?? DiaryDay() }

    func setReaction(_ day: String, _ id: String, _ level: Int?) {
        commit { s in
            var d = s.diary[day] ?? DiaryDay()
            d.reactions[id] = level
            s.diary[day] = d
        }
    }

    func setNote(_ day: String, _ note: String) {
        guard diary(day).note != note else { return }
        commit { s in var d = s.diary[day] ?? DiaryDay(); d.note = note; s.diary[day] = d }
    }

    func addFacePhoto(_ image: UIImage, day: String) {
        do {
            let id = try PhotoStore.saveFace(image)
            commit { s in var d = s.diary[day] ?? DiaryDay(); d.photos.append(id); s.diary[day] = d }
        } catch {
            show("Не получилось сохранить фото")
        }
    }

    func deleteFacePhoto(_ id: String, day: String) {
        PhotoStore.deleteFace(id)
        commit { s in s.diary[day]?.photos.removeAll { $0 == id } }
    }

    /// Все фото лица по дням, от новых к старым.
    var facePhotos: [PhotoRef] {
        state.diary.keys.sorted(by: >).flatMap { day in (state.diary[day]?.photos ?? []).map { PhotoRef(id: $0, day: day) } }
    }

    // MARK: — настройки

    func setRule(_ id: String, _ on: Bool) { commit { $0.rules[id] = on } }
    func setPregnancy(_ on: Bool) { commit { $0.settings.pregnancy = on } }
    func setReminders(_ r: Reminders) { commit { $0.reminders = r } }

    func finishOnboarding(_ o: Actions.Onboarding) {
        commit { s in
            s = Actions.applyOnboarding(s, o, today: today)
            s.onboarded = true
        }
    }

    // MARK: — копия

    /// Файл копии во временной папке — для ShareLink / «Сохранить в Файлы».
    func exportBackup(includePhotos: Bool) throws -> URL {
        let photos = includePhotos ? PhotoStore.exportFaces(ids: facePhotos.map { (id: $0.id, day: $0.day) }) : []
        let data = try Backup.encode(state, photos: photos)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ritm-kozhi-\(today).json")
        try data.write(to: url, options: .atomic)
        commit { $0.lastBackupAt = ISO8601DateFormatter().string(from: Date()) }
        return url
    }

    func importBackup(from url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let (imported, photos) = try Backup.decode(data)
        PhotoStore.importFaces(photos)
        commit { $0 = imported; $0.onboarded = true }
        show("Копия восстановлена: \(imported.items.count) средств, \(imported.entries.count) отметок")
    }

    func deleteEverything() {
        PhotoStore.deleteAll()
        commit { $0 = AppState() }
        route = .today
    }

    var backupStale: Bool {
        guard state.entries.count > 10 else { return false }
        guard let last = state.lastBackupAt, let d = ISO8601DateFormatter().date(from: last) else { return true }
        return Date().timeIntervalSince(d) > 30 * 24 * 3600
    }
}
