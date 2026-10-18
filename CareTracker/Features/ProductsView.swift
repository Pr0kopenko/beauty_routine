import SwiftUI
import PhotosUI

struct ProductsView: View {
    @Environment(AppStore.self) private var store
    @State private var picks: [PhotosPickerItem] = []
    @State private var batch: [UIImage]?
    @State private var addOne = false
    @State private var pushed: Item?

    var body: some View {
        List {
            ForEach(Catalog.blocks, id: \.id) { b in
                let items = store.activeItems.filter { $0.block == b.id }
                if !items.isEmpty {
                    Section(b.name) {
                        ForEach(items) { it in
                            NavigationLink(value: it) { ProductLine(item: it) }
                                .swipeActions {
                                    Button("В архив") { store.archive(it.id) }.tint(Theme.muted)
                                }
                        }
                    }
                }
            }
            if store.activeItems.isEmpty {
                ContentUnavailableView("Список пуст", systemImage: "drop", description: Text("Сфотографируй свои средства — распознаю названия и активы."))
            }
            Section {
                PhotosPicker(selection: $picks, maxSelectionCount: 20, matching: .images) {
                    Label("Добавить по фото (можно несколько)", systemImage: "camera.on.rectangle")
                }
                Button { addOne = true } label: { Label("Добавить вручную", systemImage: "plus") }
            } footer: {
                Text(AISettings.load().isReady ? "ИИ распознает каждое фото. Фото лица в ИИ не отправляются." : "Без ИИ найду активы по составу на фото прямо на телефоне. ИИ можно подключить в настройках.")
            }
            let archived = store.state.items.filter(\.archived)
            if !archived.isEmpty {
                Section("В архиве") {
                    ForEach(archived) { it in
                        NavigationLink(value: it) { ProductLine(item: it) }
                            .swipeActions { Button("Вернуть") { store.archive(it.id, false) }.tint(Theme.ok) }
                    }
                }
            }
        }
        .navigationTitle("Средства")
        .navigationDestination(for: Item.self) { ProductDetailView(itemId: $0.id) }
        .navigationDestination(isPresented: $addOne) { AddProductView() }
        .navigationDestination(item: $pushed) { ProductDetailView(itemId: $0.id) }
        .toolbar { ToolbarItem(placement: .topBarLeading) { SettingsButton() } }
        #if DEBUG
        .onAppear { if pushed == nil, let it = store.debugPush { pushed = it } }
        #endif
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var imgs: [UIImage] = []
                for p in items { if let d = try? await p.loadTransferable(type: Data.self), let i = UIImage(data: d) { imgs.append(i) } }
                picks = []
                if !imgs.isEmpty { batch = imgs }
            }
        }
        .sheet(isPresented: Binding(get: { batch != nil }, set: { if !$0 { batch = nil } })) {
            NavigationStack { BatchAddView(images: batch ?? []) }
        }
    }
}

struct ProductLine: View {
    @Environment(AppStore.self) private var store
    let item: Item
    var body: some View {
        HStack(spacing: 12) {
            Thumb(item: item)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { ActiveDot(color: Theme.item(item)); Text(item.name) }
                Text(subtitle).font(.footnote).foregroundStyle(Theme.muted)
            }
        }
    }
    private var subtitle: String {
        let t = store.today
        if item.isIntervalRetinoid { return Retinoid.statusText(item, Retinoid.status(item, store.state, today: t), today: t).title }
        let last = store.state.entries.filter { $0.itemId == item.id && !$0.skipped && $0.day <= t }.map(\.day).max()
        let actives = item.actives.map(Catalog.activeName).joined(separator: ", ")
        return [actives.isEmpty ? Catalog.typeName(item.type) : actives, last.map { "последний раз \(Days.when($0, today: t))" }].compactMap { $0 }.joined(separator: " · ")
    }
}

struct ProductDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let itemId: String
    @State private var editing = false
    @State private var markOther = false
    @State private var confirmDelete = false

    var body: some View {
        if let it = store.state.item(itemId) {
            content(it)
        } else {
            ContentUnavailableView("Средство удалено", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func content(_ it: Item) -> some View {
        let t = store.today
        let doneToday = store.state.entries.contains { $0.itemId == it.id && $0.day == t && !$0.skipped }
        let recent = store.state.entries.filter { $0.itemId == it.id && !$0.skipped }.sorted { $0.day > $1.day }.prefix(8)
        ScrollViewReader { scroller in
        List {
            Section {
                HStack(spacing: 14) {
                    Thumb(item: it, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(it.name).font(Theme.title)
                        Text(Array(NSOrderedSet(array: [Catalog.typeName(it.type), it.actives.map(Catalog.activeName).joined(separator: ", "), it.strength].filter { !$0.isEmpty })).compactMap { $0 as? String }.joined(separator: " · "))
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
                if !it.note.isEmpty { Text(it.note).font(.callout) }
            }
            ProductCardSections(item: it)
            if it.schedule.type == "interval" && !it.isRetinoid {
                Section {
                    Picker("Частота", selection: Binding(get: { it.schedule.freq ?? "2w" }, set: { store.setFrequency(it.id, $0) })) {
                        ForEach(Catalog.allFrequencies, id: \.self) { Text(Catalog.frequency($0).label).tag($0) }
                    }
                } footer: { Text("В остальные дни средство будет в «По желанию» с пометкой «отдыхает».") }
            }
            if it.isIntervalRetinoid {
                let st = Retinoid.status(it, store.state, today: t)
                let tx = Retinoid.statusText(it, st, today: t)
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tx.title).font(.headline)
                        Text(tx.sub).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    LabeledContent("Последний раз", value: st.last.map { Days.short($0) + (st.since.map { $0 > 0 ? " · \(Days.daysWord($0)) назад" : " · сегодня" } ?? "") } ?? "—")
                    LabeledContent("Можно снова", value: st.state == .blocked ? "—" : [.done, .resting, .paused].contains(st.state) ? (st.next.map(Days.short) ?? "—") : "сегодня")
                    WeekStrip(item: it, status: st)
                }
                AdviceCard(item: it).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                Section {
                    Picker("Частота", selection: Binding(get: { it.schedule.freq ?? "2w" }, set: { store.applyFrequency(it.id, $0) })) {
                        ForEach(Catalog.allFrequencies, id: \.self) { Text(Catalog.frequency($0).label).tag($0) }
                    }
                } header: { Text("Сейчас · \(it.form.name)") } footer: { Text(stageNote(it)) }
                Section("Как наносить") {
                    DisclosureGroup("Советы") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Горошина на всё лицо, на сухую кожу, вечером.")
                            Text("• Щиплет или шелушится — увлажняющий крем до или после («сэндвич»).")
                            Text("• Утром — SPF обязательно.")
                            Text("• Высыпания в первые недели бывают (пурджинг). Если нет покраснения и жжения, график не меняем. Дольше 8 недель — к врачу.")
                            Text("• Беременность, планирование или ГВ — ретиноиды не используют.")
                        }.font(.callout)
                    }
                }
            }
            Section {
                Button(doneToday ? "Снять сегодняшнюю отметку" : it.actives.contains("supplement") ? "Выпила сегодня" : it.isRetinoid ? "Нанесла сегодня" : "Отметить сегодня") { store.toggle(it.id) }
                Button("Отметить за другой день") { markOther = true }
            }
            Section("Статистика") {
                LabeledContent("За 7 дней", value: "\(Planner.count(it.id, store.state.entries, from: Days.add(t, -6), to: t))")
                LabeledContent("За 30 дней", value: "\(Planner.count(it.id, store.state.entries, from: Days.add(t, -29), to: t))")
            }
            Section("Последние отметки") {
                if recent.isEmpty { Text("Отметок пока нет.").foregroundStyle(Theme.muted) }
                ForEach(Array(recent)) { e in
                    HStack {
                        Text(Days.short(e.day)).monospacedDigit()
                        Text([e.slot == "evening" ? "вечер" : "утро", e.time, e.fromOnboarding ? "указано при настройке" : nil].compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                    .swipeActions { Button("Удалить", role: .destructive) { store.removeEntries([e.id]) } }
                }
            }
            Section {
                Button(it.archived ? "Вернуть из архива" : "В архив") { store.archive(it.id, !it.archived) }
                Button("Удалить вместе с отметками", role: .destructive) { confirmDelete = true }
            }
        }
        #if DEBUG
        .onAppear { if let a = UserDefaults.standard.string(forKey: "ui.scroll") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { scroller.scrollTo(a, anchor: .top) } } }
        #endif
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Изменить") { editing = true } } }
        .sheet(isPresented: $editing) { NavigationStack { EditProductView(item: it) } }
        .sheet(isPresented: $markOther) { MarkOtherDay(item: it) }
        .confirmationDialog("Удалить «\(it.name)» и все отметки?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { store.delete(it.id); dismiss() }
        }
    }

    private func stageNote(_ it: Item) -> String {
        let f = Catalog.frequency(it.schedule.freq)
        let since = it.schedule.since.map { "На этом этапе с \(Days.short($0)). " } ?? ""
        let lim = f.minDays > 1 ? "не чаще раза в \(Days.daysWord(f.minDays))" : "до \(f.maxPerWeek) раз в неделю"
        let weeks = Retinoid.ladder(it, store.state).weeks
        let step = it.form.rx ? "Рецептурная форма — шаги согласуй с врачом." : weeks > 0 ? "Шаг вверх предложу через \(weeks) нед. без реакций кожи." : "По этой схеме частоту не повышаем."
        return "\(since)Сейчас \(lim). \(step) Дни считаю сама от последнего раза."
    }
}

/// Отметка конкретного средства за прошлый день.
struct MarkOtherDay: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var slot: String

    init(item: Item) {
        self.item = item
        _slot = State(initialValue: item.block == "morning" || item.block == "supplements" ? "morning" : "evening")
    }

    var body: some View {
        let day = Days.key(date)
        let hints = Compatibility.check(itemId: item.id, day: day, slot: slot, in: store.state)
        NavigationStack {
            Form {
                DatePicker("День", selection: $date, in: ...Date(), displayedComponents: .date)
                Picker("Когда", selection: $slot) { Text("Утро").tag("morning"); Text("Вечер").tag("evening") }.pickerStyle(.segmented)
                if !hints.isEmpty { HintCard(hints: hints).listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hints.isEmpty ? "Отметить" : "Всё равно отметить") { store.mark(item.id, day: day, slot: slot, overrode: !hints.isEmpty); dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct EditProductView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var draft: Draft
    @State private var dose: String
    @State private var pick: PhotosPickerItem?

    init(item: Item) {
        self.item = item
        var r = RecognizedProduct()
        r.name = item.name; r.type = item.type.isEmpty ? "other" : item.type; r.actives = item.actives; r.retinoidForm = item.retinoidForm
        r.strength = item.strength; r.composition = item.composition; r.note = item.note
        var d = Draft(); d.product = r; d.block = item.block
        _draft = State(initialValue: d)
        _dose = State(initialValue: item.dose)
    }

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $pick, matching: .images) { Label(item.thumb == nil ? "Добавить фото" : "Другое фото", systemImage: "photo") }
            }
            ProductFields(draft: $draft, excluding: item.id)
            if draft.block == "supplements" { Section("Дозировка") { TextField("Например, 1 капсула", text: $dose) } }
        }
        .navigationTitle("Изменить")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).disabled(draft.product.name.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .onChange(of: pick) { _, p in
            guard let p else { return }
            Task { if let d = try? await p.loadTransferable(type: Data.self), let img = UIImage(data: d) { store.setThumb(item.id, image: img) } }
        }
    }

    private func save() {
        var it = store.state.item(item.id) ?? item
        let p = draft.product
        it.name = p.name.trimmingCharacters(in: .whitespaces); it.type = p.type; it.strength = p.strength; it.note = p.note; it.dose = dose
        let wasRet = it.isRetinoid
        it.actives = p.actives
        it.retinoidForm = p.actives.contains("retinoid") ? (p.retinoidForm ?? "retinol") : nil
        it.block = it.isRetinoid && draft.block != "optional" ? "evening" : draft.block
        if it.isRetinoid && it.block != "optional" {
            if it.schedule.type != "interval" { it.schedule = Schedule(type: "interval", freq: it.form.start, since: store.today) }
        } else if wasRet || it.schedule.type == "interval" || it.schedule.type != (it.block == "optional" ? "asneeded" : "daily") {
            it.schedule = Schedule(type: it.block == "optional" ? "asneeded" : "daily")
        }
        store.update(it)
        dismiss()
    }
}
