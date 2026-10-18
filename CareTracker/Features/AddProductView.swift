import SwiftUI
import PhotosUI

/// Черновик средства: результат распознавания + блок. Общий для добавления и правки.
struct Draft: Equatable {
    var product = RecognizedProduct()
    var block = "optional"
    var image: UIImage? = nil
    var error: String? = nil

    init() {}
    init(_ r: RecognizedProduct, image: UIImage? = nil, error: String? = nil) {
        product = r; block = r.suggestedBlock; self.image = image; self.error = error
        if product.name.isEmpty && !product.brand.isEmpty { product.name = product.displayName; product.brand = "" }
        else if !product.brand.isEmpty { product.name = product.displayName }
    }
}

/// Распознать фото: ИИ, если подключён, иначе — текст на телефоне. Ошибка ИИ не теряет фото.
enum Recognizer {
    static func run(_ image: UIImage) async -> Draft {
        let settings = AISettings.load()
        if settings.isReady {
            do { return Draft(try await AIClient.recognize(image, settings: settings), image: image) }
            catch {
                let local = await TextRecognizer.recognize(image)
                return Draft(local, image: image, error: (error as? LocalizedError)?.errorDescription ?? "ИИ не ответил.")
            }
        }
        return Draft(await TextRecognizer.recognize(image), image: image)
    }
}

struct AddProductView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSaved: ((Item) -> Void)? = nil

    @State private var draft = Draft()
    @State private var pick: PhotosPickerItem?
    @State private var camera = false
    @State private var busy = false
    @State private var sharing = false
    @State private var packDrafts: [Draft]?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    if let img = draft.image {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $pick, matching: .images) { Label("Фото из галереи", systemImage: "photo") }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { camera = true } label: { Label("Сфотографировать", systemImage: "camera") }
                        }
                    }
                }
                if busy { HStack { ProgressView(); Text("Распознаю…").foregroundStyle(Theme.muted) } }
                if let e = draft.error { Text(e).font(.footnote).foregroundStyle(Theme.warn) }
                if draft.image == nil {
                    Text(AISettings.load().isReady ? "Сними упаковку или состав — ИИ заполнит поля." : "Сними упаковку или состав — найду активы прямо на телефоне. Точнее — через «Спросить ChatGPT / Claude».")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            if draft.image != nil {
                Section {
                    Button { UIPasteboard.general.string = Recognition.chatPrompt; sharing = true } label: {
                        Label("Спросить ChatGPT или Claude", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    PasteButton(payloadType: String.self) { strings in
                        Task { @MainActor in applyAnswer(strings.joined(separator: "\n")) }
                    }
                    .labelStyle(.titleAndIcon)
                } footer: {
                    Text("Фото и вопрос откроются в приложении ChatGPT или Claude — работает твоя подписка. Вопрос уже скопирован: если он не вставился сам, вставь его к фото. Скопируй ответ целиком, вернись сюда и нажми «Вставить».")
                }
            }
            ProductFields(draft: $draft)
        }
        .navigationTitle("Новое средство")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить", action: save).disabled(draft.product.name.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
        }
        .onChange(of: pick) { _, p in
            guard let p else { return }
            Task {
                if let data = try? await p.loadTransferable(type: Data.self), let img = UIImage(data: data) { await recognize(img) }
                pick = nil
            }
        }
        .fullScreenCover(isPresented: $camera) { CameraPicker { img in Task { await recognize(img) } }.ignoresSafeArea() }
        .sheet(isPresented: $sharing) {
            if let img = draft.image { ShareSheet(items: [img.resized(maxSide: 1600), Recognition.chatPrompt]) }
        }
        .sheet(isPresented: Binding(get: { packDrafts != nil }, set: { if !$0 { packDrafts = nil } })) {
            NavigationStack { BatchAddView(images: [], preset: packDrafts ?? []) { packDrafts = nil; dismiss() } }
        }
    }

    private func recognize(_ img: UIImage) async {
        busy = true
        let name = draft.product.name
        var d = await Recognizer.run(img)
        if d.product.name.isEmpty { d.product.name = name }
        if !d.product.isSkincare { d.error = "Похоже, на фото не уход. Проверь поля или сними другое фото." }
        draft = d
        busy = false
    }

    /// Ответ из ChatGPT/Claude: одно средство — в форму, несколько — на проверку списком.
    private func applyAnswer(_ text: String) {
        let products = Recognition.parsePack(text)
        guard !products.isEmpty else { draft.error = "Не нашла в ответе JSON. Скопируй ответ целиком, вместе со скобками { }."; return }
        if products.count == 1 {
            let name = draft.product.name
            var d = Draft(products[0], image: draft.image)
            if d.product.name.isEmpty { d.product.name = name }
            draft = d
        } else {
            packDrafts = products.map { Draft($0) }
        }
    }

    private func save() {
        let it = store.addItem(draft.product, block: draft.block, image: draft.image)
        store.show("\(it.name) — в наборе")
        if let onSaved { onSaved(it) } else { dismiss() }
    }
}

/// Поля средства: название, тип, активы, форма ретиноида, когда показывать, подсказки совместимости.
struct ProductFields: View {
    @Environment(AppStore.self) private var store
    @Binding var draft: Draft
    var excluding: String? = nil

    var body: some View {
        Section("Средство") {
            TextField("Название", text: $draft.product.name)
            TextField("Концентрация (если есть)", text: $draft.product.strength)
            Picker("Тип", selection: $draft.product.type) {
                ForEach(Catalog.productTypes, id: \.id) { Text($0.name).tag($0.id) }
            }
            Picker("Когда показывать", selection: $draft.block) {
                ForEach(Catalog.blocks, id: \.id) { Text($0.name).tag($0.id) }
            }
        }
        Section {
            ForEach(Catalog.actives, id: \.id) { a in
                Toggle(isOn: Binding(get: { draft.product.actives.contains(a.id) }, set: { on in
                    if on { draft.product.actives.append(a.id) } else { draft.product.actives.removeAll { $0 == a.id } }
                    if a.id == "retinoid" {
                        draft.product.retinoidForm = on ? (draft.product.retinoidForm ?? "retinol") : nil
                        if on && draft.block != "optional" { draft.block = "evening" }
                    }
                    if a.id == "supplement" && on { draft.block = "supplements"; draft.product.type = "supplement" }
                    if a.id == "spf" && on { draft.block = "morning" }
                })) {
                    HStack(spacing: 8) { ActiveDot(color: Theme.active(a.id)); Text(a.name) }
                }
            }
        } header: { Text("Активы") } footer: {
            if draft.product.source == .device && !draft.product.composition.isEmpty { Text("Найдено по составу на фото. Проверь — словарь не знает всех названий.") }
        }
        if isRetinoid {
            Section {
                Picker("Форма ретиноида", selection: Binding(get: { draft.product.retinoidForm ?? "retinol" }, set: { draft.product.retinoidForm = $0 })) {
                    ForEach(Catalog.retinoidFormOrder, id: \.self) { Text(Catalog.retinoidForms[$0]!.name).tag($0) }
                }
            } footer: {
                let f = Catalog.retinoidForms[draft.product.retinoidForm ?? "retinol"]!
                Text(f.rx ? "Рецептурная форма: график и шаги согласуй с врачом. Я только помогу считать дни." : "Начнём с «\(Catalog.frequency(f.start).label.lowercased())». Шаг вверх предложу через \(f.weeks) нед., если кожа спокойна.")
            }
        }
        let preview = Compatibility.preview(actives: draft.product.actives, in: store.state, excluding: excluding)
        if !preview.isEmpty || (isRetinoid && store.state.settings.pregnancy) {
            Section("С твоим набором") {
                if isRetinoid && store.state.settings.pregnancy {
                    Label("Включён режим беременности и ГВ — ретиноиды не планирую.", systemImage: "hand.raised").foregroundStyle(Theme.warn)
                }
                ForEach(preview, id: \.self) { Text($0).font(.callout) }
            }
        }
        if !draft.product.note.isEmpty {
            Section("Заметка") { TextField("Заметка", text: $draft.product.note, axis: .vertical) }
        }
        if !draft.product.composition.isEmpty {
            Section("Состав") { Text(draft.product.composition).font(.footnote).foregroundStyle(Theme.muted).textSelection(.enabled) }
        }
    }

    private var isRetinoid: Bool { draft.product.actives.contains("retinoid") }
}

/// Камера через UIImagePickerController (нужен ключ NSCameraUsageDescription).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

// MARK: — пакетное добавление по нескольким фото

struct BatchAddView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let images: [UIImage]
    /// Уже распознанные средства (пакет от ChatGPT/Claude или из файла).
    var preset: [Draft] = []
    var onDone: (() -> Void)? = nil

    @State private var drafts: [Draft] = []
    @State private var keep: [Bool] = []
    @State private var progress = 0
    @State private var editing: Int?

    var body: some View {
        List {
            if progress < images.count {
                Section { HStack { ProgressView(); Text("Распознаю \(progress + 1) из \(images.count)…") } }
            }
            ForEach(drafts.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Toggle("", isOn: $keep[i]).labelsHidden()
                    if let img = drafts[i].image { Image(uiImage: img).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drafts[i].product.name.isEmpty ? "Без названия — нажми, чтобы вписать" : drafts[i].product.name)
                            .foregroundStyle(drafts[i].product.name.isEmpty ? Theme.warn : Theme.ink)
                        ActiveChips(actives: drafts[i].product.actives)
                        Text(confidence(drafts[i])).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(Catalog.blocks.first { $0.id == drafts[i].block }?.name ?? "").font(.caption).foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
                .onTapGesture { editing = i }
            }
        }
        .navigationTitle("Проверь набор")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Добавить \(zip(drafts, keep).filter { $0.1 && !$0.0.product.name.isEmpty }.count)", action: save)
                    .disabled(progress < images.count)
            }
        }
        .sheet(item: Binding(get: { editing.map { IndexBox(i: $0) } }, set: { editing = $0?.i })) { box in
            NavigationStack {
                Form { ProductFields(draft: $drafts[box.i]) }
                    .navigationTitle("Средство")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { editing = nil } } }
            }
        }
        .task {
            guard drafts.isEmpty else { return }
            if !preset.isEmpty { drafts = preset; keep = preset.map(\.product.isSkincare); return }
            for img in images {
                let d = await Recognizer.run(img)
                drafts.append(d); keep.append(d.product.isSkincare)
                progress += 1
            }
        }
    }

    private func confidence(_ d: Draft) -> String {
        if let e = d.error { return e }
        if d.product.source == .device { return "Распознано на телефоне — проверь" }
        switch d.product.confidence {
        case "high": return "Уверенно"
        case "low": return "Не уверена — проверь"
        default: return "Скорее всего так"
        }
    }

    private func save() {
        var n = 0
        for (d, k) in zip(drafts, keep) where k && !d.product.name.isEmpty {
            store.addItem(d.product, block: d.block, image: d.image); n += 1
        }
        store.show("Добавлено средств: \(n)")
        if let onDone { onDone() } else { dismiss() }
    }
}

struct IndexBox: Identifiable { let i: Int; var id: Int { i } }


/// Системное меню «Поделиться» — для отправки фото и вопроса в ChatGPT или Claude.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
