import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var showMark = false
    @State private var optionalOpen = false
    @State private var showAdd = false

    var body: some View {
        let t = store.today
        let plan = store.plan
        let hour = Calendar.current.component(.hour, from: Date())
        let morningFirst = hour >= Days.dayStartHour && hour < 15
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Days.long(t)).font(.subheadline).foregroundStyle(Theme.muted)
                    Text(plan.retinoid.map { Retinoid.headline($0.item, $0.status, today: t) } ?? "Сегодня")
                        .font(Theme.display).fixedSize(horizontal: false, vertical: true)
                }
                if store.backupStale { BackupBanner() }
                if let r = plan.retinoid {
                    NavigationLink(value: r.item) { RetinoidHero(item: r.item, status: r.status) }.buttonStyle(.plain)
                    AdviceCard(item: r.item)
                }
                SkinPrompt()
                if plan.allDone {
                    Label("На сегодня всё сделано. Коже — отдых.", systemImage: "checkmark.seal")
                        .foregroundStyle(Theme.ok).card()
                }
                if morningFirst {
                    BlockView(title: "Утро", kind: "morning", meta: Planner.morningTime(store.state.reminders, t), rows: plan.morning)
                    BlockView(title: "Добавки", kind: "supplements", meta: nil, rows: plan.supplements)
                    BlockView(title: "Вечер", kind: "evening", meta: store.state.reminders.evening, rows: plan.evening)
                } else {
                    BlockView(title: "Вечер", kind: "evening", meta: store.state.reminders.evening, rows: plan.evening)
                    BlockView(title: "Утро", kind: "morning", meta: Planner.morningTime(store.state.reminders, t), rows: plan.morning)
                    BlockView(title: "Добавки", kind: "supplements", meta: nil, rows: plan.supplements)
                }
                if !plan.optional.isEmpty {
                    DisclosureGroup(isExpanded: $optionalOpen) {
                        VStack(spacing: 0) { ForEach(plan.optional) { RowView(row: $0) } }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("По желанию · \(plan.optional.count)").font(.headline)
                            if !optionalOpen {
                                Text(plan.optional.prefix(3).map(\.item.name).joined(separator: ", ")).font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                        }
                    }
                    .card()
                }
                if plan.scheduled.isEmpty && plan.optional.isEmpty {
                    ContentUnavailableView("Пока нет средств", systemImage: "drop", description: Text("Добавь их во вкладке «Средства» или кнопкой «+»."))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 80)
        }
        .background(Theme.paper)
        .navigationDestination(for: Item.self) { ProductDetailView(itemId: $0.id) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { SettingsButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showMark = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Отметить другое средство или другой день")
            }
        }
        .sheet(isPresented: $showMark) { MarkSheet() }
        .sheet(isPresented: $showAdd) { NavigationStack { AddProductView() } }
        .refreshable { store.refreshDay() }
        #if DEBUG
        .onAppear {
            if store.debugSheet == "mark" { showMark = true }
            if store.debugSheet == "add" { showAdd = true }
        }
        #endif
    }
}

// MARK: — герой ретиноида

struct RetinoidHero: View {
    @Environment(AppStore.self) private var store
    let item: Item
    let status: RetinoidStatus

    var body: some View {
        let raw = Retinoid.statusText(item, status, today: store.today)
        // Заголовок экрана уже говорит «Сегодня вечер — …», в карточке не повторяем.
        let title = raw.title == Retinoid.headline(item, status, today: store.today)
            ? "\(item.name) · \(Catalog.frequency(item.schedule.freq).label.lowercased())" : raw.title
        let text = (title: title, sub: raw.sub)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Ring(status: status)
                VStack(alignment: .leading, spacing: 4) {
                    Text(text.title).font(.headline)
                    Text(text.sub).font(.subheadline).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            WeekStrip(item: item, status: status)
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(warm ? Theme.active("retinoid") : .clear, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private var warm: Bool { [.today, .overdue, .notStarted].contains(status.state) }
}

struct Ring: View {
    let status: RetinoidStatus
    var body: some View {
        let (n, unit, pct): (String, String, Double) = {
            switch status.state {
            case .done: return ("✓", "", 1)
            case .notStarted: return ("0", "старт", 0)
            case .paused, .blocked: return ("II", "пауза", 0)
            case .resting:
                let left = status.minDays - (status.since ?? 0)
                return ("\(max(left, 1))", Days.plural(max(left, 1), "день", "дня", "дней"), Double(status.since ?? 0) / Double(max(status.minDays, 1)))
            case .today, .overdue:
                let s = status.since ?? 0
                return ("\(s)", Days.plural(s, "день", "дня", "дней"), 1)
            }
        }()
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 6)
            Circle().trim(from: 0, to: pct).stroke(Theme.active("retinoid"), style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(n).font(.title3.bold().monospacedDigit())
                if !unit.isEmpty { Text(unit).font(.caption2).foregroundStyle(Theme.muted) }
            }
        }
        .frame(width: 64, height: 64)
    }
}

/// Неделя с понедельника: когда был ретиноид и когда можно снова.
struct WeekStrip: View {
    @Environment(AppStore.self) private var store
    let item: Item
    let status: RetinoidStatus

    var body: some View {
        let t = store.today
        let start = Days.add(t, -((Days.weekday(t) + 6) % 7))
        let days = Set(Retinoid.days(store.state))
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let k = Days.add(start, i)
                let done = days.contains(k)
                let planned = !done && status.next == k && k >= t
                VStack(spacing: 2) {
                    Text("\(Days.parts(k).2)").font(.callout.bold().monospacedDigit())
                    Text(Days.weekdaysShort[Days.weekday(k)]).font(.caption2)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(done ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(done || planned ? Theme.active("retinoid") : (k == t ? Theme.ink : .clear), style: StrokeStyle(lineWidth: k == t ? 2 : 1.5, dash: planned ? [4, 3] : [])))
                .accessibilityLabel("\(Days.short(k)): \(done ? "нанесла" : planned ? "можно снова" : "нет")")
            }
        }
    }
}

struct AdviceCard: View {
    @Environment(AppStore.self) private var store
    let item: Item
    var body: some View {
        if let a = Retinoid.advice(item, store.state, today: store.today) {
            VStack(alignment: .leading, spacing: 10) {
                Label(a.text, systemImage: a.kind == .up ? "arrow.up.circle" : "exclamationmark.triangle")
                    .foregroundStyle(a.kind == .up ? Theme.ok : Theme.warn)
                HStack {
                    switch a.kind {
                    case .up:
                        Button("Перейти") { store.applyFrequency(item.id, a.to) }.buttonStyle(.borderedProminent)
                        Button("Через неделю") { store.snoozeAdvice(item.id) }.buttonStyle(.bordered)
                    case .down:
                        Button("Шаг назад") { store.applyFrequency(item.id, a.to) }.buttonStyle(.borderedProminent)
                    case .doctor:
                        Button("Вернуться на 2 раза в неделю") { store.applyFrequency(item.id, a.to) }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(a.kind == .up ? Theme.okSoft : Theme.warnSoft, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct SkinPrompt: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        let d = store.state.diary[store.today]
        let lvl = Planner.reactionLevel(store.state, store.today)
        Button { store.route = .skin } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let lvl, let d {
                        Text("Кожа сегодня: \(Catalog.levels[lvl])").font(.headline)
                        let list = Catalog.reactions.compactMap { r in d.reactions[r.id].flatMap { $0 > 0 ? "\(r.name.lowercased()) — \(Catalog.levels[$0])" : nil } }
                        Text(list.isEmpty ? "без реакций" : list.joined(separator: ", ")).font(.footnote).foregroundStyle(Theme.muted)
                    } else {
                        Text("Как кожа сегодня?").font(.headline)
                        Text("Покраснение, сухость, высыпания — 10 секунд. Помогает вести ретиноид.").font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

struct BackupBanner: View {
    @Environment(AppStore.self) private var store
    @State private var url: URL?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Пора сохранить копию").font(.headline)
            Text("Данные лежат только в этом телефоне. Копия в «Файлах» спасёт их при смене телефона.").font(.footnote).foregroundStyle(Theme.muted)
            if let url {
                ShareLink(item: url) { Label("Отправить копию", systemImage: "square.and.arrow.up") }
            } else {
                Button("Сделать копию") { url = try? store.exportBackup(includePhotos: false) }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: — блоки и строки

struct BlockView: View {
    @Environment(AppStore.self) private var store
    let title: String
    let kind: String
    let meta: String?
    let rows: [PlanRow]

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title).font(.headline)
                    if let meta { Text(meta).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted) }
                    Spacer()
                    if rows.filter({ !$0.done && $0.deferred == nil }).count > 1 {
                        Button("Отметить всё") { store.markBlock(kind: kind == "supplements" ? "supplements" : kind, day: store.today) }.font(.subheadline)
                    }
                }
                .padding(.bottom, 6)
                ForEach(rows) { RowView(row: $0) }
            }
            .card()
        }
    }
}

struct RowView: View {
    @Environment(AppStore.self) private var store
    let row: PlanRow
    @State private var showReason = false

    var body: some View {
        Button {
            if row.deferred != nil && !row.done { showReason = true } else { store.toggle(row.item.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: row.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(row.done ? Theme.ok : Theme.line)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        ActiveDot(color: Theme.item(row.item))
                        Text(row.item.name).font(.body).strikethrough(false).foregroundStyle(row.deferred != nil ? Theme.muted : Theme.ink)
                    }
                    if let sub { Text(sub).font(.footnote).foregroundStyle(row.accent != nil ? Theme.accent : Theme.muted) }
                }
                Spacer(minLength: 0)
                if let pill { Text(pill).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 3).background(Theme.accentSoft, in: Capsule()).foregroundStyle(Theme.accent) }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(row.done ? .isSelected : [])
        .contextMenu {
            NavigationLink(value: row.item) { Label("О средстве", systemImage: "info.circle") }
            if row.deferred != nil && !row.done { Button("Всё равно отметить") { store.requestMark(row.item.id) } }
        }
        .alert(row.deferred ?? "", isPresented: $showReason) {
            Button("Всё равно отметить") { store.requestMark(row.item.id) }
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(reasonText)
        }
    }

    private var reasonText: String {
        let st = row.status
        if let st, st.state == .resting, let next = st.next {
            return "Ретиноид был \(Days.when(st.last ?? store.today, today: store.today)). По частоте «\(Catalog.frequency(row.item.schedule.freq).label.lowercased())» следующий — \(Days.when(next, today: store.today))."
        }
        if row.deferred?.hasPrefix("Пауза") == true { return "Кожа реагирует — сильные активы лучше отложить, пока она не успокоится: мягкое очищение, увлажнение и SPF." }
        if row.deferred?.contains("ретиноида") == true { return "Сегодня вечер ретиноида. Это средство лучше в другой вечер или утром." }
        return "Можно отметить всё равно — это подсказка, не запрет."
    }

    private var sub: String? {
        let it = row.item, t = store.today
        if let d = row.deferred, !row.done { return d }
        if let a = row.accent { return a }
        if it.actives.contains("supplement") {
            let streak = Planner.streak(it.id, store.state, today: t, includeToday: row.done)
            if row.done { return streak > 1 ? "Выпила · \(Days.daysWord(streak)) подряд" : "Выпила" }
            let time = Planner.morningTime(store.state.reminders, t)
            return Days.hhmm() >= time ? "Пора выпить" : "Напомню в \(time)"
        }
        if let st = row.status, it.isRetinoid {
            if st.state == .done, let n = st.next { return "Нанесла · следующий \(Days.when(n, today: t))" }
            return Catalog.frequency(it.schedule.freq).label
        }
        if row.done, let e = row.entry, let time = e.time { return "\(e.slot == "evening" ? "вечер" : "утро") · \(time)" }
        if !it.dose.isEmpty { return it.dose }
        return nil
    }

    private var pill: String? {
        guard let st = row.status, !row.done else { return nil }
        switch st.state {
        case .overdue: return "пора"
        case .today, .notStarted: return "можно"
        default: return nil
        }
    }
}
