import SwiftUI

/// «+» на «Сегодня»: отметить любое средство за любой день, в том числе новое.
struct MarkSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var slot = Calendar.current.component(.hour, from: Date()) < 15 ? "morning" : "evening"
    @State private var query = ""
    @State private var hinted: (item: Item, hints: [Hint])?
    @State private var addNew = false

    private var day: String { Days.key(date) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("День", selection: $date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                    Picker("Когда", selection: $slot) {
                        Text("Утро").tag("morning")
                        Text("Вечер").tag("evening")
                    }
                    .pickerStyle(.segmented)
                }
                if let h = hinted {
                    Section("\(h.item.name)") {
                        HintCard(hints: h.hints).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                        Button("Всё равно отметить") { finish(h.item, overrode: true) }
                        Button("Не отмечать", role: .cancel) { hinted = nil }
                    }
                }
                let recent = Planner.recentProducts(store.state, store.today).filter { !$0.archived }
                if query.isEmpty && !recent.isEmpty {
                    Section("Недавние") { ForEach(recent) { row($0) } }
                }
                Section(query.isEmpty ? "Все средства" : "Найдено") {
                    ForEach(filtered) { row($0) }
                    Button { addNew = true } label: { Label("Новое средство", systemImage: "plus.circle") }
                }
            }
            .searchable(text: $query, prompt: "Найти средство")
            .navigationTitle("Отметить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .navigationDestination(isPresented: $addNew) {
                AddProductView { item in finishNew(item) }
            }
        }
        .presentationDetents([.large])
    }

    private var filtered: [Item] {
        let list = store.activeItems
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter { $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q) }
    }

    private func row(_ it: Item) -> some View {
        let done = store.state.entries.contains { $0.itemId == it.id && $0.day == day && !$0.skipped }
        return Button {
            let hints = Compatibility.check(itemId: it.id, day: day, slot: slot, in: store.state)
            if hints.isEmpty { finish(it, overrode: false) } else { withAnimation { hinted = (it, hints) } }
        } label: {
            HStack(spacing: 12) {
                Thumb(item: it, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(it.name).foregroundStyle(Theme.ink)
                    ActiveChips(actives: it.actives)
                }
                Spacer()
                if done { Image(systemName: "checkmark").foregroundStyle(Theme.ok).accessibilityLabel("уже отмечено") }
            }
        }
        .disabled(done)
    }

    private func finish(_ it: Item, overrode: Bool) {
        store.mark(it.id, day: day, slot: slot, overrode: overrode)
        dismiss()
    }

    private func finishNew(_ it: Item) {
        addNew = false
        let hints = Compatibility.check(itemId: it.id, day: day, slot: slot, in: store.state)
        if hints.isEmpty { finish(it, overrode: false) } else { hinted = (it, hints) }
    }
}
