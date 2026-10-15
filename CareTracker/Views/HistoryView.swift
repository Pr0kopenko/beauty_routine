import SwiftUI
import SwiftData

/// Все отметки, сгруппированные по дням.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CareEntry.date, order: .reverse) private var entries: [CareEntry]

    private var days: [(day: Date, entries: [CareEntry])] {
        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(days, id: \.day) { day in
                    Section(day.day.formatted(date: .complete, time: .omitted)) {
                        ForEach(day.entries) { entry in
                            HStack {
                                Image(systemName: entry.product?.kind.symbol ?? "questionmark")
                                    .foregroundStyle(.tint)
                                Text(entry.product?.name ?? "Удалённое средство")
                                Spacer()
                                Text(entry.date.formatted(date: .omitted, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { day.entries[$0] }.forEach(context.delete)
                        }
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("Пока пусто", systemImage: "calendar",
                                           description: Text("Отметки появятся здесь."))
                }
            }
            .navigationTitle("История")
        }
    }
}
