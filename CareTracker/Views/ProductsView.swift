import SwiftUI
import SwiftData

/// Список средств и добавок: добавление и удаление.
struct ProductsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Product.name) private var products: [Product]
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(products) { product in
                    Label(product.name, systemImage: product.kind.symbol)
                }
                .onDelete { offsets in
                    offsets.map { products[$0] }.forEach(context.delete)
                }
            }
            .navigationTitle("Средства")
            .toolbar {
                Button("Добавить", systemImage: "plus") { showingAdd = true }
            }
            .sheet(isPresented: $showingAdd) {
                AddProductView()
            }
        }
    }
}

struct AddProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: ProductKind = .serum

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $name)
                Picker("Тип", selection: $kind) {
                    ForEach(ProductKind.allCases) { Text($0.title).tag($0) }
                }
            }
            .navigationTitle("Новое средство")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        context.insert(Product(name: name.trimmingCharacters(in: .whitespaces), kind: kind))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
