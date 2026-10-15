import SwiftUI
import SwiftData

/// Отметки за сегодня: тап по средству — «сделала», повторный тап — отменить.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Product.name) private var products: [Product]

    var body: some View {
        NavigationStack {
            List {
                ForEach(ProductKind.allCases) { kind in
                    let items = products.filter { $0.kind == kind }
                    if !items.isEmpty {
                        Section(kind.title) {
                            ForEach(items) { product in
                                row(for: product)
                            }
                        }
                    }
                }
            }
            .overlay {
                if products.isEmpty {
                    ContentUnavailableView(
                        "Нет средств",
                        systemImage: "drop",
                        description: Text("Добавьте ретинол, сыворотки или магний на вкладке «Средства».")
                    )
                }
            }
            .navigationTitle("Сегодня")
        }
    }

    private func row(for product: Product) -> some View {
        let done = product.wasUsed(on: .now)
        return Button {
            toggle(product)
        } label: {
            HStack {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? .green : .secondary)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(product.name)
                    if let last = product.lastUsed, !done {
                        Text("Последний раз: \(last.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.primary)
    }

    private func toggle(_ product: Product) {
        let today = product.entries.filter { Calendar.current.isDateInToday($0.date) }
        if today.isEmpty {
            context.insert(CareEntry(product: product))
        } else {
            today.forEach(context.delete)
        }
    }
}
