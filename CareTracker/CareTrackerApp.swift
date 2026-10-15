import SwiftUI
import SwiftData

@main
struct CareTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Product.self, CareEntry.self])
    }
}
