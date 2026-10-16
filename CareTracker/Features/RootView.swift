import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.route) {
            NavigationStack { TodayView() }
                .tabItem { Label("Сегодня", systemImage: "sun.and.horizon") }.tag(Tab.today)
            NavigationStack { SkinView() }
                .tabItem { Label("Кожа", systemImage: "face.smiling") }.tag(Tab.skin)
            NavigationStack { ProductsView() }
                .tabItem { Label("Средства", systemImage: "drop") }.tag(Tab.products)
            NavigationStack { HistoryView() }
                .tabItem { Label("История", systemImage: "calendar") }.tag(Tab.history)
        }
        .sheet(isPresented: $store.showSettings) { NavigationStack { SettingsView() } }
        .sheet(item: $store.pending) { p in HintSheet(pending: p).presentationDetents([.medium, .large]) }
        .fullScreenCover(isPresented: Binding(get: { !store.state.onboarded }, set: { _ in })) { OnboardingView() }
        .overlay(alignment: .bottom) {
            if let t = store.toast {
                ToastView(toast: t) { store.toast = nil }
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: t.id) {
                        try? await Task.sleep(for: .seconds(5))
                        if store.toast?.id == t.id { store.toast = nil }
                    }
            }
        }
        .animation(.snappy, value: store.toast)
        .sensoryFeedback(.success, trigger: store.state.entries.count)
    }
}

/// Отметка с подсказками совместимости: можно отметить всё равно — это подсказка, не запрет.
struct HintSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pending: PendingMark

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.state.item(pending.itemId)?.name ?? "Средство").font(Theme.title)
            Text("\(Days.when(pending.day, today: store.today).capFirst), \(pending.slot == "morning" ? "утро" : "вечер")").foregroundStyle(Theme.muted)
            HintCard(hints: pending.hints)
            Spacer()
            Button { store.confirmPending(); dismiss() } label: { Text("Всё равно отметить").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Button { store.pending = nil; dismiss() } label: { Text("Не отмечать").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered).controlSize(.large)
        }
        .padding(20)
    }
}

/// Кнопка настроек в шапке каждой вкладки.
struct SettingsButton: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Button { store.showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Настройки")
    }
}

extension String {
    var capFirst: String { prefix(1).uppercased() + dropFirst() }
}
