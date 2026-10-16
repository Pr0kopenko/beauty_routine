import SwiftUI
import PhotosUI

struct SkinView: View {
    @Environment(AppStore.self) private var store
    @State private var day: String?
    @State private var note = ""
    @State private var picks: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var compareMode = false
    @State private var selected: [String] = []
    @State private var comparing: ComparePair?
    @State private var viewing: PhotoRef?

    private var d: String { day ?? store.today }

    var body: some View {
        let diary = store.diary(d)
        let irr = Retinoid.irritation(store.state, d)
        let breakouts = diary.reactions["breakouts"] ?? 0
        List {
            if d != store.today {
                Button("← К сегодняшнему дню") { day = nil }
            }
            Section {
                ForEach(Catalog.reactions, id: \.id) { r in
                    LevelPicker(title: r.name, level: Binding(get: { diary.reactions[r.id] }, set: { store.setReaction(d, r.id, $0) }))
                }
            } header: { Text(Days.long(d)) } footer: { Text("Покраснение, сухость и жжение ведут паузу ретиноида. Высыпания — отдельно: в первые недели это может быть пурджинг.") }

            if let irr, irr >= 2 {
                Label(irr >= 3 ? "Кожа сильно раздражена. Пауза во всех активах, пока не успокоится: мягкое очищение, увлажнение, SPF. Если не проходит за несколько дней — к дерматологу."
                                : "Кожа раздражена. Ретиноид и кислоты — пауза на 2–3 дня, потом шаг назад по частоте.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Theme.warn)
            } else if breakouts >= 1, let weeks = weeksOnRetinoid, weeks < 8 {
                Label("Высыпания в первые недели ретиноида бывают — это может быть пурджинг. Если нет покраснения и жжения, график не меняем. Дольше 8 недель — к врачу.", systemImage: "drop")
            }

            Section("Заметка") {
                TextField("Например: щиплет вокруг носа после ретиналя", text: $note, axis: .vertical)
                    .lineLimit(2...6)
                    .onSubmit { store.setNote(d, note) }
                    .onChange(of: note) { _, v in store.setNote(d, v) }
            }

            Section("За 48 часов на коже") {
                let recent = Planner.recentProducts(store.state, d)
                if recent.isEmpty { Text("Отметок нет.").foregroundStyle(Theme.muted) }
                ForEach(recent) { it in HStack(spacing: 8) { ActiveDot(color: Theme.item(it)); Text(it.name) } }
            }

            Section {
                PhotoGrid(photos: store.facePhotos, compareMode: compareMode, selected: $selected) { ref in
                    if compareMode { toggleSelect(ref.id) } else { viewing = ref }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                if !compareMode {
                    HStack {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { camera = true } label: { Label("Снять", systemImage: "camera") }.buttonStyle(.bordered)
                        }
                        PhotosPicker(selection: $picks, maxSelectionCount: 10, matching: .images) { Label("Из галереи", systemImage: "photo") }.buttonStyle(.bordered)
                    }
                }
            } header: {
                HStack {
                    Text("Фото лица")
                    Spacer()
                    if store.facePhotos.count >= 2 {
                        Button(compareMode ? "Отмена" : "Сравнить") { compareMode.toggle(); selected = [] }.textCase(nil)
                    }
                }
            } footer: {
                Text(compareMode ? "Выбери два фото: «до» и «после». Выбрано: \(selected.count)." : "Снимай при одном свете и с одного ракурса — так видна разница. Фото хранятся только на этом телефоне и в ИИ не отправляются.")
            }

            let past = pastDays
            if !past.isEmpty {
                Section("Раньше") {
                    ForEach(past, id: \.self) { k in
                        Button { day = k } label: { PastDayRow(day: k) }.buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Кожа")
        .toolbar { ToolbarItem(placement: .topBarLeading) { SettingsButton() } }
        .onAppear { note = store.diary(d).note }
        .onChange(of: day) { _, _ in note = store.diary(d).note }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for p in items { if let data = try? await p.loadTransferable(type: Data.self), let img = UIImage(data: data) { store.addFacePhoto(img, day: d) } }
                picks = []
                store.show("Фото сохранено")
            }
        }
        .fullScreenCover(isPresented: $camera) { CameraPicker { store.addFacePhoto($0, day: d) }.ignoresSafeArea() }
        .fullScreenCover(item: $comparing) { CompareView(pair: $0) }
        .sheet(item: $viewing) { PhotoViewer(ref: $0) }
    }

    private func toggleSelect(_ id: String) {
        if let i = selected.firstIndex(of: id) { selected.remove(at: i); return }
        selected.append(id)
        if selected.count == 2 {
            let photos = store.facePhotos
            let a = photos.first { $0.id == selected[0] }!, b = photos.first { $0.id == selected[1] }!
            comparing = a.day <= b.day ? ComparePair(before: a, after: b) : ComparePair(before: b, after: a)
            selected = []; compareMode = false
        }
    }

    private var weeksOnRetinoid: Int? {
        Retinoid.days(store.state).first.map { Days.between($0, d) / 7 }
    }

    private var pastDays: [String] {
        store.state.diary.keys.filter { k in
            guard k != d, let v = store.state.diary[k] else { return false }
            return !v.reactions.isEmpty || !v.note.isEmpty || !v.photos.isEmpty
        }.sorted(by: >).prefix(21).map { $0 }
    }
}

struct PastDayRow: View {
    @Environment(AppStore.self) private var store
    let day: String
    var body: some View {
        let v = store.diary(day)
        let l = Planner.reactionLevel(store.state, day)
        let parts = [Catalog.reactions.compactMap { r in v.reactions[r.id].flatMap { $0 > 0 ? "\(r.name.lowercased()) \(Catalog.levels[$0])" : nil } }.joined(separator: ", "), v.note].filter { !$0.isEmpty }
        HStack(spacing: 10) {
            Circle().fill(levelColor(l)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(Days.short(day) + (l.map { " · \(Catalog.levels[$0])" } ?? ""))
                Text(parts.isEmpty ? (v.photos.isEmpty ? "" : "фото") : parts.joined(separator: " · ")).font(.footnote).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
    }
    private func levelColor(_ l: Int?) -> Color {
        switch l ?? 0 { case 3: return Theme.warn; case 2: return Theme.accent; case 1: return Theme.accentSoft; default: return Theme.okSoft }
    }
}

struct PhotoRef: Identifiable, Hashable { let id: String; let day: String }
struct ComparePair: Identifiable { let before: PhotoRef; let after: PhotoRef; var id: String { before.id + after.id } }

struct PhotoGrid: View {
    @Environment(AppStore.self) private var store
    let photos: [PhotoRef]
    let compareMode: Bool
    @Binding var selected: [String]
    let tap: (PhotoRef) -> Void

    var body: some View {
        if photos.isEmpty {
            Text("Пока нет фото. Первое — до начала нового средства, дальше раз в 1–2 недели.").font(.footnote).foregroundStyle(Theme.muted)
        } else {
            let starts = Planner.firstUse(store.state)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                ForEach(photos) { p in
                    Button { tap(p) } label: {
                        ZStack(alignment: .bottomLeading) {
                            FaceImage(id: p.id).frame(height: 120).clipped()
                            VStack(alignment: .leading, spacing: 0) {
                                Text(Days.short(p.day)).font(.caption.bold())
                                if let s = starts.first(where: { $0.value <= p.day && Days.between($0.value, p.day) <= 3 }), let it = store.state.item(s.key) {
                                    Text("новое: \(it.name)").font(.caption2).lineLimit(1)
                                }
                            }
                            .foregroundStyle(.white).padding(6).shadow(radius: 2)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected.contains(p.id) ? Theme.accent : .clear, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Фото лица \(Days.short(p.day))")
                }
            }
        }
    }
}

struct FaceImage: View {
    let id: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() } else { Theme.bg }
        }
        .frame(maxWidth: .infinity)
        .task(id: id) { image = await Task.detached { PhotoStore.face(id) }.value }
    }
}

struct PhotoViewer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let ref: PhotoRef
    @State private var confirm = false
    var body: some View {
        NavigationStack {
            FaceImage(id: ref.id).scaledToFit()
                .navigationTitle(Days.short(ref.day))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                    ToolbarItem(placement: .destructiveAction) { Button("Удалить", role: .destructive) { confirm = true } }
                }
                .confirmationDialog("Удалить фото?", isPresented: $confirm) {
                    Button("Удалить", role: .destructive) { store.deleteFacePhoto(ref.id, day: ref.day); dismiss() }
                }
        }
    }
}

/// До / после: шторка на весь экран.
struct CompareView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pair: ComparePair
    @State private var x: CGFloat = 0.5

    var body: some View {
        let starts = Planner.firstUse(store.state)
        let between = store.state.items.filter { it in starts[it.id].map { $0 > pair.before.day && $0 <= pair.after.day } ?? false }
        NavigationStack {
            VStack(spacing: 12) {
                Text("\(Days.short(pair.before.day)) → \(Days.short(pair.after.day)) · \(Days.daysWord(max(0, Days.between(pair.before.day, pair.after.day))))")
                    .foregroundStyle(Theme.muted)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        FaceImage(id: pair.before.id).frame(width: g.size.width, height: g.size.height).clipped()
                        FaceImage(id: pair.after.id).frame(width: g.size.width, height: g.size.height).clipped()
                            .mask(alignment: .trailing) { Rectangle().frame(width: g.size.width * (1 - x)) }
                        Rectangle().fill(.white).frame(width: 2).offset(x: g.size.width * x - 1).shadow(radius: 2)
                        HStack { Text("до"); Spacer(); Text("после") }.font(.caption.bold()).foregroundStyle(.white).padding(10).frame(maxHeight: .infinity, alignment: .top).shadow(radius: 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in x = min(max(v.location.x / g.size.width, 0), 1) })
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Slider(value: $x).accessibilityLabel("Шторка сравнения")
                if !between.isEmpty {
                    Text("За это время начала: \(between.map(\.name).joined(separator: ", ")).").font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .padding(16)
            .navigationTitle("До и после")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
    }
}
