import SwiftUI
import PhotosUI

/// Карточка «что с этим делать»: секции для списка на экране средства.
struct ProductCardSections: View {
    @Environment(AppStore.self) private var store
    let item: Item
    @State private var planSheet: PlanSheet?
    @State private var photoKind: PhotoKind?
    @State private var pick: PhotosPickerItem?
    @State private var busy: String?
    @State private var showMyths = false

    enum PhotoKind: String, Identifiable { case composition, leaflet; var id: String { rawValue } }
    struct PlanSheet: Identifiable { let id = Ids.make(); var plan: IntroPlan; var leaflet: String? }

    var body: some View {
        let card = CardBuilder.build(item, in: store.state)
        Group {
            if let t = card.time {
                Section("Когда") { SourcedText(line: t) }
            }
            Section {
                if let i = card.intro { SourcedText(line: i) }
                if !card.scheduleKnown {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Схема производителя не найдена", systemImage: "questionmark.circle").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                        Text(AISettings.load().isReady ? "Поищу на сайте бренда при распознавании. Если на упаковке или вкладыше есть инструкция — сфотографируй её, она точнее общего правила."
                                                       : "Пока показываю общее правило по активу. Если на упаковке или вкладыше есть инструкция — сфотографируй её или введи схему вручную.")
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Button { photoKind = .leaflet } label: { Label("Сфотографировать вкладыш или упаковку", systemImage: "doc.text.viewfinder") }
                    Button { planSheet = PlanSheet(plan: defaultPlan(), leaflet: nil) } label: { Label("Ввести схему вручную", systemImage: "square.and.pencil") }
                    Button { var p = defaultPlan(); p.source = "doctor"; planSheet = PlanSheet(plan: p, leaflet: nil) } label: { Label("Схема от врача или косметолога", systemImage: "stethoscope") }
                } else if let p = item.introPlan {
                    if let q = p.quote, !q.isEmpty { Text("«\(q)»").font(.footnote).italic().foregroundStyle(Theme.muted) }
                    if let u = p.url, let url = URL(string: u) { Link("Источник", destination: url).font(.footnote) }
                    Button("Изменить схему") { planSheet = PlanSheet(plan: p, leaflet: nil) }
                    Button("Убрать свою схему", role: .destructive) { store.setIntroPlan(item.id, nil) }
                }
            } header: { Text("Как вводить") }
            .id("intro")

            Section {
                if card.found.isEmpty {
                    Text("Активов не отмечено.").foregroundStyle(Theme.muted)
                }
                ForEach(card.found, id: \.active.id) { f in
                    HStack(alignment: .top, spacing: 10) {
                        ActiveDot(color: Theme.active(Knowledge.coarse(f.active) ?? "other"))
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.active.nameRu + (f.pct.map { " · \(fmt($0))%" } ?? ""))
                            Text(f.levelText + (f.strength >= 3 ? " · сильный актив" : f.strength == 2 ? " · умеренный" : " · мягкий"))
                                .font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                }
                Button { photoKind = .composition } label: {
                    Label(item.composition.isEmpty ? "Сфотографировать состав — точнее по концентрации" : "Обновить состав по фото", systemImage: "text.viewfinder")
                }
                if busy != nil { HStack { ProgressView(); Text(busy!).foregroundStyle(Theme.muted) } }
            } header: { Text("Что внутри") } footer: {
                Text(card.fromComposition ? "Найдено по составу. Концентрацию оцениваю по проценту на упаковке или по месту в составе." : "По отмеченным активам. С фото состава оценка будет точнее.")
            }

            if !card.compat.isEmpty || !card.myths.isEmpty {
                Section {
                    ForEach(card.compat) { n in CompatRow(note: n) }
                    if !card.myths.isEmpty {
                        DisclosureGroup("Можно вместе, хотя часто пишут обратное · \(card.myths.count)", isExpanded: $showMyths) {
                            ForEach(card.myths) { n in CompatRow(note: n) }
                        }
                        .font(.subheadline)
                    }
                } header: { Text("С твоим набором") }
                .id("compat")
            }

            if !card.rosacea.isEmpty || !card.triggers.isEmpty || !card.sensitive.isEmpty {
                Section {
                    ForEach(card.rosacea, id: \.self) { Text($0).font(.callout) }
                    if !card.triggers.isEmpty {
                        Label("В составе есть частые раздражители при розацеа: \(card.triggers.joined(separator: ", ")).", systemImage: "exclamationmark.triangle")
                            .font(.callout).foregroundStyle(Theme.warn)
                    }
                    if !store.state.settings.rosacea || card.rosacea.isEmpty {
                        ForEach(card.sensitive, id: \.self) { Text($0).font(.callout) }
                    }
                } header: { Text(store.state.settings.rosacea ? "При розацеа" : "Для чувствительной кожи") }
            }

            if !card.safety.isEmpty || !card.expect.isEmpty {
                Section("Важно знать") {
                    ForEach(card.safety, id: \.self) { SourcedText(line: $0) }
                    ForEach(card.expect, id: \.self) { Text($0).font(.callout).foregroundStyle(Theme.muted) }
                }
            }

            if !card.sources.isEmpty {
                Section {
                    ForEach(card.sources, id: \.id) { s in
                        if let u = URL(string: s.url) { Link(s.title, destination: u).font(.footnote).lineLimit(2) }
                    }
                } header: { Text("Источники") } footer: {
                    Text("Справка по общим правилам, не медицинская рекомендация. При розацеа, беременности и рецептурных средствах ориентируйся на врача.")
                }
            }
        }
        .sheet(item: $planSheet) { s in ManualPlanView(item: item, initial: s.plan, leaflet: s.leaflet) }
        .sheet(item: $photoKind) { kind in
            PhotoSourceSheet(title: kind == .composition ? "Фото состава" : "Фото инструкции") { img in
                photoKind = nil
                Task { await handle(img, kind: kind) }
            }
            .presentationDetents([.height(220)])
        }
    }

    private func defaultPlan() -> IntroPlan {
        let start = item.isRetinoid ? Retinoid.startFrequency(item, store.state) : (Knowledge.startFrequency(actives: item.actives, composition: item.composition) ?? "daily")
        return IntroPlan(source: "user", start: start, stepUpWeeks: 2, max: "daily", timeOfDay: item.isRetinoid ? "evening" : nil)
    }

    private func handle(_ img: UIImage, kind: PhotoKind) async {
        busy = "Читаю текст на фото…"
        let text = await TextRecognizer.text(in: img)
        busy = nil
        guard !text.isEmpty else { store.show("Текст на фото не найден. Сними поближе и при хорошем свете."); return }
        switch kind {
        case .composition:
            store.setComposition(item.id, text)
            store.show("Состав обновлён")
        case .leaflet:
            var plan = LeafletParser.parse(text) ?? defaultPlan()
            plan.source = "leaflet"
            planSheet = PlanSheet(plan: plan, leaflet: text)
        }
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v).replacingOccurrences(of: ".", with: ",") }
}

struct SourcedText: View {
    let line: CardLine
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(line.text).font(.callout)
            Text(sourceLabel).font(.caption).foregroundStyle(line.source == "kb" ? Theme.muted : Theme.ok)
        }
    }
    private var sourceLabel: String {
        let name = line.source == "kb" ? "общее правило по составу" : (IntroPlan.sourceNames.first { $0.id == line.source }?.name.lowercased() ?? line.source)
        let conf = ["high": "высокая", "medium": "средняя", "low": "низкая"][line.confidence ?? ""]
        return "Источник: \(name)" + (conf.map { " · уверенность \($0)" } ?? "")
    }
}

struct CompatRow: View {
    let note: CompatNote
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(note.otherName).font(.subheadline.bold())
                Spacer()
                Text(Knowledge.verdictText[note.verdict] ?? note.verdict).font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.15), in: Capsule()).foregroundStyle(color)
            }
            if !note.pairLabel.isEmpty { Text(note.pairLabel).font(.caption).foregroundStyle(Theme.muted) }
            Text(note.why).font(.footnote)
            if let c = note.condition { Text(c).font(.caption).foregroundStyle(Theme.muted) }
            Text("Уверенность: \(["high": "высокая", "medium": "средняя", "low": "низкая"][note.confidence] ?? note.confidence)").font(.caption2).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 2)
    }
    private var color: Color {
        switch Knowledge.verdictRank[note.verdict] ?? 1 {
        case 4...: return Theme.warn
        case 2, 3: return Theme.accent
        case 0: return Theme.ok
        default: return Theme.muted
        }
    }
}

/// Камера или галерея — одной шторкой.
struct PhotoSourceSheet: View {
    let title: String
    let onImage: (UIImage) -> Void
    @State private var pick: PhotosPickerItem?
    @State private var camera = false
    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(.headline)
            Text("Положи на ровную поверхность, без бликов, весь текст в кадре.").font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { camera = true } label: { Label("Снять", systemImage: "camera").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                }
                PhotosPicker(selection: $pick, matching: .images) { Label("Из галереи", systemImage: "photo").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding(20)
        .onChange(of: pick) { _, p in
            guard let p else { return }
            Task { if let d = try? await p.loadTransferable(type: Data.self), let img = UIImage(data: d) { onImage(img) } }
        }
        .fullScreenCover(isPresented: $camera) { CameraPicker { onImage($0) }.ignoresSafeArea() }
    }
}

/// Ручной ввод схемы (или проверка распознанной со вкладыша).
struct ManualPlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State var plan: IntroPlan
    let leaflet: String?
    @State private var stepUp: Bool

    init(item: Item, initial: IntroPlan, leaflet: String?) {
        self.item = item
        _plan = State(initialValue: initial)
        self.leaflet = leaflet
        _stepUp = State(initialValue: (initial.stepUpWeeks ?? 0) > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                if leaflet != nil {
                    Section {
                        Text(plan.quote.map { "Нашла в тексте: «\($0)»" } ?? "Частоту в тексте не нашла — заполни по инструкции.").font(.callout)
                    } footer: { Text("Проверь поля: распознавание текста может ошибаться.") }
                }
                Section("Откуда схема") {
                    Picker("Источник", selection: $plan.source) {
                        ForEach(IntroPlan.sourceNames, id: \.id) { Text($0.name).tag($0.id) }
                    }
                }
                Section("Схема") {
                    Picker("Когда", selection: Binding(get: { plan.timeOfDay ?? "any" }, set: { plan.timeOfDay = $0 })) {
                        Text("Вечером").tag("evening"); Text("Утром").tag("morning"); Text("Утром или вечером").tag("any")
                    }
                    Picker("Начать с", selection: $plan.start) {
                        ForEach(Catalog.allFrequencies, id: \.self) { Text(Catalog.frequency($0).label).tag($0) }
                    }
                    Toggle("Постепенно повышать", isOn: $stepUp)
                    if stepUp {
                        Stepper("Шаг: раз в \(plan.stepUpWeeks ?? 2) нед.", value: Binding(get: { plan.stepUpWeeks ?? 2 }, set: { plan.stepUpWeeks = $0 }), in: 1...12)
                        Picker("До", selection: $plan.max) {
                            ForEach(Catalog.allFrequencies, id: \.self) { Text(Catalog.frequency($0).label).tag($0) }
                        }
                    }
                }
                Section("Заметка") {
                    TextField("Например: только на сухую кожу, поверх крема", text: $plan.note, axis: .vertical)
                }
                if let leaflet {
                    Section("Текст с фото") { Text(leaflet).font(.footnote).foregroundStyle(Theme.muted).textSelection(.enabled) }
                }
            }
            .navigationTitle("Схема введения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var p = plan
                        if !stepUp { p.stepUpWeeks = nil; p.max = p.start }
                        let all = Catalog.allFrequencies
                        if (all.firstIndex(of: p.max) ?? 0) < (all.firstIndex(of: p.start) ?? 0) { p.max = p.start }
                        p.addedAt = store.today
                        store.setIntroPlan(item.id, p)
                        dismiss()
                    }
                }
            }
        }
    }
}
