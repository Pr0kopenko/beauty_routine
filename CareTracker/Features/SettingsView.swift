import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("faceLock") private var faceLock = false

    var body: some View {
        List {
            Section {
                NavigationLink { RemindersView() } label: { Label("Напоминания", systemImage: "bell") }
                NavigationLink { RulesView() } label: { Label("Правила совместимости", systemImage: "checklist") }
                NavigationLink { AISettingsView() } label: {
                    LabeledContent { Text(AISettings.load().isReady ? "подключено" : "на телефоне") } label: { Label("Распознавание", systemImage: "sparkles") }
                }
            }
            Section {
                Toggle("Розацеа", isOn: Binding(get: { store.state.settings.rosacea }, set: { store.setSkin(rosacea: $0) }))
                Toggle("Чувствительная кожа", isOn: Binding(get: { store.state.settings.sensitive }, set: { store.setSkin(sensitive: $0) }))
                Picker("Ретиноиды", selection: Binding(get: { store.state.settings.retinoidProfile }, set: { store.setSkin(profile: $0) })) {
                    Text("Авто").tag("auto"); Text("Стандартно").tag("standard"); Text("Осторожно").tag("cautious")
                }
            } header: { Text("Кожа") } footer: {
                Text("Сейчас: \(store.state.settings.cautious ? "осторожный режим — 1 раз в неделю и медленные шаги" : "стандартный режим — 2 раза в неделю → через день → каждый вечер"). «Авто» включает осторожный режим при розацеа или чувствительной коже. При розацеа ретиноиды лучше вводить вместе с дерматологом.")
            }
            Section {
                Toggle(isOn: Binding(get: { store.state.settings.pregnancy }, set: { store.setPregnancy($0) })) {
                    VStack(alignment: .leading) {
                        Text("Беременность, планирование, ГВ")
                        Text("Ретиноиды на паузе, подсказки мягче").font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
                Toggle("Вход по Face ID", isOn: $faceLock)
            } footer: { Text("Face ID закрывает приложение целиком — в нём фото лица.") }
            Section("Данные") { NavigationLink { BackupView() } label: { Label("Копия и перенос", systemImage: "externaldrive") } }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ритм кожи (бета)").font(.headline)
                    Text("Приложение помогает помнить график и подсказывает по общим правилам. Это не медицинский совет: при сильной реакции, беременности или рецептурных средствах ориентируйся на врача.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    Text("Версия \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")").font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
        .navigationTitle("Настройки")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
    }
}

// MARK: — напоминания

struct RemindersView: View {
    @Environment(AppStore.self) private var store
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        let r = store.state.reminders
        let tomorrow = Days.add(store.today, 1)
        List {
            if status != .authorized && status != .provisional {
                Section {
                    Button("Разрешить уведомления") { Task { _ = await Notifications.shared.requestPermission(); await refresh(); store.refreshDay() } }
                    if status == .denied {
                        Button("Открыть настройки iPhone") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                    }
                } footer: { Text(status == .denied ? "Уведомления выключены в настройках iPhone." : "Без разрешения напоминать не получится.") }
            }
            Section {
                time("Утро в будни", r.morning.weekdays) { var n = r; n.morning.weekdays = $0; store.setReminders(n) }
                time("Утро в выходные", r.morning.weekend) { var n = r; n.morning.weekend = $0; store.setReminders(n) }
                time("Вечер", r.evening) { var n = r; n.evening = $0; store.setReminders(n) }
            } footer: { Text("Утром — утренний уход и добавки, вечером — вечерний уход и ретиноид, если сегодня его день.") }
            Section {
                Toggle("Завтра утром — другое время", isOn: Binding(get: { r.overrides[tomorrow] != nil }, set: { on in
                    var n = r; n.overrides[tomorrow] = on ? Planner.morningTime(r, tomorrow) : nil; store.setReminders(n)
                }))
                if r.overrides[tomorrow] != nil {
                    time("Завтра, \(Days.short(tomorrow))", r.overrides[tomorrow]!) { var n = r; n.overrides[tomorrow] = $0; store.setReminders(n) }
                }
            }
            Section {
                Picker("Повторить, если не отмечено", selection: Binding(get: { r.followUpMinutes }, set: { var n = r; n.followUpMinutes = $0; store.setReminders(n) })) {
                    Text("Не повторять").tag(0)
                    Text("Через 30 минут").tag(30)
                    Text("Через час").tag(60)
                    Text("Через 2 часа").tag(120)
                }
                time("Не беспокоить после", r.quietAfter) { var n = r; n.quietAfter = $0; store.setReminders(n) }
            } footer: { Text("Из уведомления можно сразу нажать «Сделала», «Через 30 минут» или «Сегодня пропускаю».") }
        }
        .navigationTitle("Напоминания")
        .task { await refresh() }
    }

    private func refresh() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func time(_ title: String, _ value: String, set: @escaping (String) -> Void) -> some View {
        DatePicker(title, selection: Binding(get: { dateFrom(value) }, set: { set(Days.hhmm($0)) }), displayedComponents: .hourAndMinute)
    }

    private func dateFrom(_ hhmm: String) -> Date {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(bySettingHour: p.first ?? 8, minute: p.count > 1 ? p[1] : 0, second: 0, of: Date()) ?? Date()
    }
}

// MARK: — правила

struct RulesView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section {
                ForEach(Catalog.rules, id: \.id) { rule in
                    Toggle(isOn: Binding(get: { store.state.ruleOn(rule.id) }, set: { store.setRule(rule.id, $0) })) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rule.text)
                            if !rule.sub.isEmpty { Text(rule.sub).font(.footnote).foregroundStyle(Theme.muted) }
                            HStack(spacing: 8) {
                                Text("Уверенность: \(rule.confidence)").font(.caption).foregroundStyle(confidenceColor(rule.confidence))
                                if let s = rule.source, let u = URL(string: s) { Link("источник", destination: u).font(.caption) }
                            }
                        }
                    }
                }
            } footer: {
                Text("Подсказки не запрещают отметку. «Высокий» — есть исследования или позиция дерматологов; «низкий» — перестраховка; «эвристика» — правило приложения.")
            }
        }
        .navigationTitle("Правила")
    }
    private func confidenceColor(_ c: String) -> Color {
        switch c { case "высокий": return Theme.ok; case "средний": return Theme.accent; default: return Theme.muted }
    }
}

// MARK: — ИИ

struct AISettingsView: View {
    @State private var s = AISettings.load()
    @State private var secret = ""
    @State private var testing = false
    @State private var result: String?

    var body: some View {
        Form {
            Section {
                Picker("Как распознавать", selection: $s.provider) {
                    Text("Claude (свой ключ)").tag("claude")
                    Text("ChatGPT (свой ключ)").tag("openai")
                    Text("Инвайт-код").tag("proxy")
                }
                .onChange(of: s.provider) { _, p in
                    s.model = p == "openai" ? "gpt-4.1-mini" : p == "proxy" ? "gpt-4.1-mini" : "claude-haiku-5-5"
                    secret = Keychain.get(p)
                    result = nil
                }
            } footer: {
                Text("Без ИИ активы находятся по составу на фото прямо на телефоне — название впишешь сама. В ИИ уходит только фото упаковки, фото лица — никогда.")
            }
            Section {
                if s.provider == "proxy" {
                    TextField("Адрес сервера", text: $s.proxyURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Инвайт-код", text: $secret)
                    Picker("Нейросеть", selection: $s.model) {
                        Text("ChatGPT (gpt-4.1-mini)").tag("gpt-4.1-mini")
                        Text("Claude Haiku").tag("claude-haiku-5-5")
                    }
                } else {
                    SecureField(s.provider == "openai" ? "Ключ OpenAI (sk-…)" : "Ключ Anthropic (sk-ant-…)", text: $secret)
                    TextField("Модель", text: $s.model).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            } header: { Text(s.provider == "proxy" ? "Сервер друзей" : "Ключ") } footer: {
                Text(s.provider == "proxy" ? "Код даёт тот, кто поднял сервер (см. proxy/README.md в репозитории)." : "Ключ хранится в связке ключей iPhone и не попадает в копию данных.")
            }
            Section {
                Button(testing ? "Проверяю…" : "Сохранить и проверить") { Task { await test() } }.disabled(testing || secret.isEmpty)
                if let result { Text(result).font(.footnote) }
                if Keychain.get(s.provider).isEmpty == false {
                    Button("Удалить ключ", role: .destructive) { Keychain.set("", for: s.provider); secret = ""; result = nil }
                }
            }
        }
        .navigationTitle("Распознавание")
        .onAppear { secret = Keychain.get(s.provider) }
    }

    private func test() async {
        testing = true
        Keychain.set(secret.trimmingCharacters(in: .whitespacesAndNewlines), for: s.provider)
        s.save()
        do { try await AIClient.test(s); result = "Работает ✓" }
        catch { result = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        testing = false
    }
}

// MARK: — копия

struct BackupView: View {
    @Environment(AppStore.self) private var store
    @State private var withPhotos = false
    @State private var url: URL?
    @State private var importing = false
    @State private var error: String?
    @State private var confirmImport: URL?
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                Toggle("Вместе с фото лица", isOn: $withPhotos).onChange(of: withPhotos) { _, _ in url = nil }
                if let url {
                    ShareLink(item: url) { Label("Отправить или сохранить в «Файлы»", systemImage: "square.and.arrow.up") }
                } else {
                    Button("Сделать копию") {
                        do { url = try store.exportBackup(includePhotos: withPhotos) } catch { self.error = error.localizedDescription }
                    }
                }
            } header: { Text("Копия") } footer: {
                Text(lastBackup + " Копия без фото весит мало — её удобно отправить себе. С фото — только в надёжное место: это фото лица.")
            }
            Section {
                Button("Восстановить из файла") { importing = true }
            } header: { Text("Перенос") } footer: {
                Text("Подходит копия из веб-версии (PWA): «Ещё → Сохранить копию» там и «Восстановить» здесь. Текущие данные заменятся.")
            }
            if let error { Section { Text(error).foregroundStyle(Theme.warn) } }
            Section {
                Button("Удалить все данные", role: .destructive) { confirmDelete = true }
            } footer: { Text("Удалятся средства, отметки, дневник и фото на этом телефоне. Ключ ИИ останется в связке ключей.") }
        }
        .navigationTitle("Копия и перенос")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { r in
            if case .success(let u) = r { confirmImport = u }
        }
        .confirmationDialog("Заменить текущие данные копией?", isPresented: Binding(get: { confirmImport != nil }, set: { if !$0 { confirmImport = nil } }), titleVisibility: .visible) {
            Button("Заменить", role: .destructive) {
                guard let u = confirmImport else { return }
                do { try store.importBackup(from: u); error = nil } catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
                confirmImport = nil
            }
        }
        .confirmationDialog("Удалить все данные без возможности восстановления?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить всё", role: .destructive) { store.deleteEverything(); store.showSettings = false }
        }
    }

    private var lastBackup: String {
        guard let s = store.state.lastBackupAt, let d = ISO8601DateFormatter().date(from: s) else { return "Копий ещё не было." }
        return "Последняя копия — \(Days.short(Days.key(d)))."
    }
}
