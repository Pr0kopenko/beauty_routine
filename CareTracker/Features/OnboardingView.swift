import SwiftUI
import PhotosUI

/// Первый запуск: приветствие → полка → ретиноид → время → «Готово».
struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var step = 0
    @State private var o = Actions.Onboarding()
    @State private var lastDate = Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date()
    @State private var picks: [PhotosPickerItem] = []
    @State private var batch: [UIImage]?
    @State private var addOne = false
    @State private var importing = false
    @State private var importError: String?

    private var retinoid: Item? { store.activeItems.first(where: \.isRetinoid) }
    /// Шаги: 0 приветствие, 1 полка, 2 последний раз, 3 частота, 4 время, 5 готово. Без ретиноида 2 и 3 пропускаем.
    private func next() { withAnimation { step = step == 1 && retinoid == nil ? 4 : step + 1 } }
    private func back() { withAnimation { step = step == 4 && retinoid == nil ? 1 : max(0, step - 1) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if step > 0 && step < 5 {
                        ProgressView(value: Double(step), total: 4).tint(Theme.accent)
                    }
                    switch step {
                    case 0: welcome
                    case 1: shelf
                    case 2: lastTime
                    case 3: frequency
                    case 4: times
                    default: done
                    }
                }
                .padding(20)
            }
            .background(Theme.paper)
            .toolbar {
                if step > 0 && step < 5 { ToolbarItem(placement: .topBarLeading) { Button("Назад", action: back) } }
            }
            .navigationDestination(isPresented: $addOne) { AddProductView() }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var imgs: [UIImage] = []
                for p in items { if let d = try? await p.loadTransferable(type: Data.self), let i = UIImage(data: d) { imgs.append(i) } }
                picks = []
                if !imgs.isEmpty { batch = imgs }
            }
        }
        .sheet(isPresented: Binding(get: { batch != nil }, set: { if !$0 { batch = nil } })) {
            NavigationStack { BatchAddView(images: batch ?? []) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { r in
            if case .success(let u) = r {
                do { try store.importBackup(from: u) } catch { importError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: — шаги

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ритм кожи").font(Theme.display).padding(.top, 40)
            Text("Помню за тебя, когда был ретиноид, что с чем не смешивать и выпит ли магний.").font(.title3)
            VStack(alignment: .leading, spacing: 12) {
                feature("calendar.badge.clock", "График ретиноида", "Считаю дни от последнего раза и предлагаю шаг вверх, когда кожа готова.")
                feature("checklist", "Совместимость", "Подсказываю, что лучше не наносить в один вечер, — по данным исследований.")
                feature("bell", "Напоминания", "Утро, добавки и вечер — «Сделала» прямо из уведомления.")
                feature("face.smiling", "Дневник кожи", "Реакции и фото «до / после». Всё хранится только на телефоне.")
            }
            Text("Это не медицинский совет. При сильной реакции, беременности или рецептурных средствах ориентируйся на врача.")
                .font(.footnote).foregroundStyle(Theme.muted)
            Button { next() } label: { Text("Начать").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
            Button("У меня есть копия из веб-версии") { importing = true }.frame(maxWidth: .infinity)
            if let importError { Text(importError).font(.footnote).foregroundStyle(Theme.warn) }
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(text).font(.subheadline).foregroundStyle(Theme.muted) }
        }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Шаг 1 из 4").font(.subheadline).foregroundStyle(Theme.muted)
            Text("Что у тебя на полке?").font(Theme.display)
            Text(store.activeItems.isEmpty ? "Сфотографируй всё, чем пользуешься: умывалки, сыворотки, кремы, SPF, добавки. Можно выбрать сразу много фото." : "Проверь набор и добавь забытое — например, утренний крем или второй SPF.")
                .foregroundStyle(Theme.muted)
            PhotosPicker(selection: $picks, maxSelectionCount: 20, matching: .images) {
                Label(store.activeItems.isEmpty ? "Выбрать фото средств" : "Добавить ещё по фото", systemImage: "camera.on.rectangle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Button { addOne = true } label: { Text("Добавить вручную").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
            if !AISettings.load().isReady {
                Text("Без ИИ найду активы по составу на обороте, название впишешь сама. ИИ (Claude или ChatGPT) можно подключить позже в настройках.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 0) {
                ForEach(store.activeItems) { it in
                    HStack(spacing: 12) {
                        Thumb(item: it, size: 36)
                        VStack(alignment: .leading, spacing: 2) { Text(it.name); ActiveChips(actives: it.actives) }
                        Spacer()
                        Menu(Catalog.blocks.first { $0.id == it.block }?.name ?? "") {
                            ForEach(Catalog.blocks, id: \.id) { b in
                                Button(b.name) {
                                    var n = it; n.block = it.isRetinoid && b.id != "optional" ? "evening" : b.id
                                    if !n.isRetinoid { n.schedule = Schedule(type: n.block == "optional" ? "asneeded" : "daily") }
                                    store.update(n)
                                }
                            }
                        }
                        .font(.footnote)
                        Button { store.delete(it.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.line) }
                            .accessibilityLabel("Убрать \(it.name)")
                    }
                    .padding(.vertical, 8)
                }
            }
            Button { next() } label: { Text("Дальше").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(store.activeItems.isEmpty)
        }
    }

    private var lastTime: some View {
        let name = retinoid?.name ?? "ретиноид"
        let opts: [(String, String)] = [("1", "Вчера"), ("3", "2–3 дня назад"), ("7", "Неделю назад"), ("date", "Выбрать дату"), ("never", "Ещё не начинала")]
        return VStack(alignment: .leading, spacing: 16) {
            Text("Шаг 2 из 4").font(.subheadline).foregroundStyle(Theme.muted)
            Text("Когда последний раз был \(name.lowercased())?").font(Theme.display)
            Text("Посчитаю, когда можно снова. Не помнишь точно — выбери примерно, потом поправим.").foregroundStyle(Theme.muted)
            ForEach(opts.indices, id: \.self) { i in
                let (k, l) = opts[i]
                Button {
                    o.last = k
                    if k == "date" { o.date = Days.key(lastDate) }
                } label: {
                    HStack {
                        Text(l)
                        Spacer()
                        if o.last == k, let n = Int(k) { Text(Days.dayMonth(Days.add(store.today, -n))).foregroundStyle(Theme.accent) }
                        if o.last == k { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                    }
                    .padding(14).background(Theme.raise, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(o.last == k ? Theme.accent : Theme.line))
                }
                .buttonStyle(.plain)
            }
            if o.last == "date" {
                DatePicker("Дата", selection: $lastDate, in: ...Date(), displayedComponents: .date)
                    .onChange(of: lastDate) { _, d in o.date = Days.key(d) }
            }
            Button { next() } label: { Text("Дальше").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(o.last == nil)
        }
    }

    private var frequency: some View {
        let form = retinoid?.form ?? Catalog.retinoidForms["retinol"]!
        let current = o.freq ?? retinoid?.schedule.freq ?? (o.last == "never" ? form.start : "2w")
        return VStack(alignment: .leading, spacing: 16) {
            Text("Шаг 3 из 4").font(.subheadline).foregroundStyle(Theme.muted)
            Text("Как часто теперь?").font(Theme.display)
            Text(o.last == "never" ? "Для формы «\(form.name.lowercased())» обычно начинают с «\(Catalog.frequency(form.start).label.lowercased())». Дальше сама предложу шаг вверх, если кожа спокойна." : "Выбери, как наносишь сейчас. Дальше сама предложу шаг вверх, если кожа спокойна.")
                .foregroundStyle(Theme.muted)
            ForEach(Catalog.stageOrder, id: \.self) { k in
                let f = Catalog.frequency(k)
                Button { o.freq = k } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.label)
                            Text(k == form.start ? "старт для этой формы" : f.minDays > 1 ? "раз в \(Days.daysWord(f.minDays))" : "до \(f.maxPerWeek) в неделю").font(.footnote).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if current == k { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                    }
                    .padding(14).background(Theme.raise, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(current == k ? Theme.accent : Theme.line))
                }
                .buttonStyle(.plain)
            }
            if form.rx { Text("Рецептурная форма: частоту назначает врач. Я буду считать дни и напоминать.").font(.footnote).foregroundStyle(Theme.warn) }
            Button { o.freq = current; next() } label: { Text("Дальше").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private var times: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Шаг 4 из 4").font(.subheadline).foregroundStyle(Theme.muted)
            Text("Когда напоминать?").font(Theme.display)
            Text("Утром — утренний уход и добавки, вечером — вечерний уход.").foregroundStyle(Theme.muted)
            VStack(spacing: 12) {
                timeRow("Утро в будни", $o.weekdays)
                timeRow("Утро в выходные", $o.weekend)
                timeRow("Вечер", $o.evening)
            }
            .card()
            Text("Разовый сдвиг («завтра в 7:15») — в настройках напоминаний.").font(.footnote).foregroundStyle(Theme.muted)
            Button {
                Task { _ = await Notifications.shared.requestPermission(); next() }
            } label: { Text("Разрешить уведомления и дальше").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private func timeRow(_ title: String, _ value: Binding<String>) -> some View {
        DatePicker(title, selection: Binding(get: {
            let p = value.wrappedValue.split(separator: ":").compactMap { Int($0) }
            return Calendar.current.date(bySettingHour: p.first ?? 8, minute: p.count > 1 ? p[1] : 0, second: 0, of: Date()) ?? Date()
        }, set: { value.wrappedValue = Days.hhmm($0) }), displayedComponents: .hourAndMinute)
    }

    private var done: some View {
        let preview = Actions.applyOnboarding(store.state, o, today: store.today)
        let ret = preview.items.first { $0.isRetinoid && !$0.archived }
        let st = ret.map { Retinoid.status($0, preview, today: store.today) }
        let title: String = {
            guard let ret, let st else { return "Всё готово" }
            let next = st.state == .resting ? (st.next ?? store.today) : store.today
            return next == store.today ? "\(ret.name) можно сегодня вечером" : "\(ret.name) можно \(Days.when(next, today: store.today)), \(Days.dayMonth(next))"
        }()
        return VStack(alignment: .leading, spacing: 18) {
            Text("Готово").font(.subheadline).foregroundStyle(Theme.muted).padding(.top, 20)
            Text(title).font(Theme.display)
            VStack(alignment: .leading, spacing: 12) {
                if ret != nil { feature("calendar.badge.clock", "График ретиноида", "Скажу, отдыхает он или пора, и когда можно шаг вверх.") }
                feature("checklist", "Совместимость", "Подскажу, что лучше не смешивать в один вечер.")
                feature("sun.max", "SPF", "Утром напомню, если накануне были ретиноид или кислоты.")
                feature("face.smiling", "Дневник кожи", "Реакции и фото «до / после» — видно, что работает.")
            }
            .card()
            Button {
                store.finishOnboarding(o)
            } label: { Text("Начать").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}
