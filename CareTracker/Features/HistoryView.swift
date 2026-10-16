import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var month: (y: Int, m: Int) = { let p = Days.parts(Days.key()); return (p.0, p.1) }()
    @State private var selected: String?
    @State private var moving: Entry?

    var body: some View {
        let t = store.today
        let sel = selected ?? t
        let byDay = Actions.monthDays(store.state, year: month.y, month: month.m)
        let first = String(format: "%04d-%02d-01", month.y, month.m)
        let pad = (Days.weekday(first) + 6) % 7
        let count = daysIn(month.y, month.m)
        let isCurrent = String(t.prefix(7)) == String(first.prefix(7))
        let monthEnd = isCurrent ? t : String(format: "%04d-%02d-%02d", month.y, month.m, count)
        List {
            Section {
                HStack {
                    Text("\(Days.monthsNom[month.m - 1]) \(String(month.y))").font(.headline)
                    Spacer()
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Предыдущий месяц")
                    Button { shift(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Следующий месяц").padding(.leading, 16)
                }
                .buttonStyle(.borderless)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(["пн", "вт", "ср", "чт", "пт", "сб", "вс"], id: \.self) { Text($0).font(.caption).foregroundStyle(Theme.muted) }
                    ForEach(0..<pad, id: \.self) { _ in Color.clear.frame(height: 44) }
                    ForEach(1...count, id: \.self) { d in
                        let k = String(format: "%04d-%02d-%02d", month.y, month.m, d)
                        DayCell(day: k, entries: byDay[k] ?? [], selected: k == sel, today: k == t, future: k > t) { selected = k }
                    }
                }
                HStack(spacing: 14) {
                    HStack(spacing: 4) { RoundedRectangle(cornerRadius: 3).fill(Theme.accentSoft).frame(width: 14, height: 14); Text("ретиноид") }
                    HStack(spacing: 4) { ActiveDot(color: Theme.muted, size: 6); Text("другие средства") }
                }
                .font(.caption).foregroundStyle(Theme.muted)
            }
            if month.y * 100 + month.m <= Int(t.prefix(4))! * 100 + Int(t.dropFirst(5).prefix(2))! {
                Section("Итоги месяца") { MonthSummary(first: first, end: monthEnd) }
            }
            Section(Days.long(sel)) {
                let entries = (store.state.entries.filter { $0.day == sel && !$0.skipped }).sorted { a, b in a.slot == b.slot ? (a.time ?? "") < (b.time ?? "") : a.slot == "morning" }
                if entries.isEmpty { Text(sel > t ? "Этот день ещё не наступил." : "В этот день отметок нет.").foregroundStyle(Theme.muted) }
                ForEach(entries) { e in
                    if let it = store.state.item(e.itemId) {
                        HStack(spacing: 10) {
                            ActiveDot(color: Theme.item(it))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(it.name)
                                Text([e.slot == "evening" ? "вечер" : "утро", e.time, e.overrode ? "вопреки подсказке" : nil, e.fromOnboarding ? "указано при настройке" : nil].compactMap { $0 }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(Theme.muted)
                            }
                        }
                        .swipeActions {
                            Button("Удалить", role: .destructive) { store.removeEntries([e.id]) }
                            Button("Перенести") { moving = e }.tint(Theme.accent)
                        }
                    }
                }
            }
        }
        .navigationTitle("История")
        .toolbar { ToolbarItem(placement: .topBarLeading) { SettingsButton() } }
        .sheet(item: $moving) { e in MoveEntrySheet(entry: e) }
    }

    private func shift(_ n: Int) {
        var m = month.m + n, y = month.y
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        month = (y, m)
    }
    private func daysIn(_ y: Int, _ m: Int) -> Int {
        let d = Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: 1))!
        return Calendar(identifier: .gregorian).range(of: .day, in: .month, for: d)!.count
    }
}

struct DayCell: View {
    @Environment(AppStore.self) private var store
    let day: String
    let entries: [Entry]
    let selected: Bool
    let today: Bool
    let future: Bool
    let tap: () -> Void

    var body: some View {
        let items = Array(Set(entries.map(\.itemId))).compactMap { store.state.item($0) }
        let ret = items.contains(where: \.isRetinoid)
        let dots = items.filter { !$0.isRetinoid }.sorted { ($0.actives.contains("supplement") ? 1 : 0) < ($1.actives.contains("supplement") ? 1 : 0) }.prefix(4)
        Button(action: tap) {
            VStack(spacing: 3) {
                Text("\(Days.parts(day).2)").font(.callout.monospacedDigit()).foregroundStyle(future ? Theme.muted : Theme.ink)
                HStack(spacing: 2) { ForEach(Array(dots)) { ActiveDot(color: Theme.item($0), size: 5) } }.frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(ret ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Theme.accent : today ? Theme.ink : .clear, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Days.long(day) + (items.isEmpty ? "" : ": " + items.map(\.name).joined(separator: ", ")))
    }
}

struct MonthSummary: View {
    @Environment(AppStore.self) private var store
    let first: String
    let end: String

    var body: some View {
        let ret = store.activeItems.first(where: \.isRetinoid)
        let days = Retinoid.days(store.state).filter { $0 >= first && $0 <= end }
        if let ret, !days.isEmpty {
            let minDays = Catalog.frequency(ret.schedule.freq).minDays
            let early = days.indices.filter { $0 > 0 && Days.between(days[$0 - 1], days[$0]) < minDays }.count
            LabeledContent("Ретиноид", value: "\(days.count) \(Days.plural(days.count, "вечер", "вечера", "вечеров"))" + (early > 0 ? " · \(early) раньше интервала" : " · все по плану"))
        }
        ForEach(store.activeItems.filter { $0.block == "supplements" }) { s in
            let firstDay = store.state.entries.filter { $0.itemId == s.id && !$0.skipped }.map(\.day).min()
            let from = [first, store.state.startedAt, firstDay].compactMap { $0 }.filter { $0 <= end }.max() ?? first
            let total = from > end ? 0 : Days.between(from, end) + 1
            if total > 0 {
                LabeledContent(s.name, value: "\(Planner.count(s.id, store.state.entries, from: from, to: end)) из \(total)")
            }
        }
        let reactions = store.state.diary.filter { $0.key >= first && $0.key <= end && ($0.value.reactions.values.max() ?? 0) >= 2 }.count
        LabeledContent("Дни с заметной реакцией кожи", value: "\(reactions)")
    }
}

struct MoveEntrySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: Entry
    @State private var date: Date
    @State private var slot: String

    init(entry: Entry) {
        self.entry = entry
        _date = State(initialValue: Days.noon(entry.day))
        _slot = State(initialValue: entry.slot)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("День", selection: $date, in: ...Date(), displayedComponents: .date)
                Picker("Когда", selection: $slot) { Text("Утро").tag("morning"); Text("Вечер").tag("evening") }.pickerStyle(.segmented)
            }
            .navigationTitle(store.state.item(entry.itemId)?.name ?? "Отметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Перенести") { store.moveEntry(entry.id, to: Days.key(date), slot: slot); dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
