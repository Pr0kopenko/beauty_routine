import SwiftUI
import LocalAuthentication

@main
struct RitmApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var phase
    @AppStorage("faceLock") private var faceLock = false
    @State private var locked = UserDefaults.standard.bool(forKey: "faceLock")

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(store)
                    .tint(Theme.accent)
                if locked { LockView(unlock: unlock) }
            }
            .onAppear {
                Notifications.shared.setup(store: store)
                store.refreshDay()
                if locked { unlock() }
            }
            .onChange(of: phase) { _, p in
                switch p {
                case .active: store.refreshDay()
                case .background: if faceLock { locked = true }
                default: break
                }
            }
        }
    }

    private func unlock() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Открыть дневник кожи и фото") { ok, _ in
            DispatchQueue.main.async { if ok { locked = false } }
        }
    }
}

struct LockView: View {
    let unlock: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Ритм кожи").font(Theme.title)
            Button("Открыть", action: unlock).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }
}
