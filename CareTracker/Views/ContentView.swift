import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сегодня", systemImage: "checklist") }
            HistoryView()
                .tabItem { Label("История", systemImage: "calendar") }
            ProductsView()
                .tabItem { Label("Средства", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Product.self, CareEntry.self], inMemory: true)
}
