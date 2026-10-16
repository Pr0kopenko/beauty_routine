import SwiftUI

/// Цвета как у PWA: тёплая бумага, янтарный акцент ретиноида, цвет у каждого актива.
enum Theme {
    static let bg = dyn(0xEFEDF0, 0x141216)
    static let paper = dyn(0xFBFAFB, 0x1C1920)
    static let raise = dyn(0xFFFFFF, 0x221E26)
    static let ink = dyn(0x2A2230, 0xEEE9F0)
    static let muted = dyn(0x6A6371, 0xA9A1AF)
    static let line = dyn(0xDDD9DF, 0x39333E)
    static let accent = dyn(0xB9770E, 0xE3A73A)
    static let accentSoft = dyn(0xF6E7C8, 0x2E2619)
    static let ok = dyn(0x2E7A66, 0x5DBFA6)
    static let okSoft = dyn(0xDCEFE8, 0x173129)
    static let warn = dyn(0xA8432A, 0xE88B6B)
    static let warnSoft = dyn(0xF7E0D8, 0x3A2119)

    private static let activeColors: [String: Color] = [
        "ret": dyn(0xC98A12, 0xE3A73A), "acid": dyn(0xC24A72, 0xE07098), "az": dyn(0xC24A72, 0xE07098),
        "ni": dyn(0x4B5BA8, 0x8C97E0), "pep": dyn(0x7A5BA6, 0xA88BD3), "spf": dyn(0x4E8FC4, 0x7FB4E0),
        "sup": dyn(0x5E6B78, 0x9AA7B4), "vc": dyn(0xD2691E, 0xF0995A),
    ]
    static func active(_ id: String) -> Color {
        let key = Catalog.actives.first { $0.id == id }?.color ?? "sup"
        return activeColors[key] ?? muted
    }
    /// Цвет средства — по самому сильному активу.
    static func item(_ item: Item) -> Color {
        let order = ["retinoid", "aha", "bha", "pha", "bpo", "exfoliant", "azelaic", "vitc", "copper", "peptides", "niacinamide", "spf", "supplement"]
        let a = order.first { item.actives.contains($0) }
        return a.map(active) ?? line
    }

    static let display = Font.system(.largeTitle, design: .serif).weight(.regular)
    static let title = Font.system(.title2, design: .serif)

    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: — общие элементы

struct ActiveDot: View {
    let color: Color
    var size: CGFloat = 9
    var body: some View { Circle().fill(color).frame(width: size, height: size).accessibilityHidden(true) }
}

struct Thumb: View {
    let item: Item
    var size: CGFloat = 40
    var body: some View {
        Group {
            if let img = PhotoStore.thumb(item.thumb) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack { Theme.bg; ActiveDot(color: Theme.item(item), size: size / 3.5) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 4, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct ActiveChips: View {
    let actives: [String]
    var body: some View {
        if actives.isEmpty {
            Text("без активов").font(.footnote).foregroundStyle(Theme.muted)
        } else {
            Text(actives.map(Catalog.activeName).joined(separator: " · ")).font(.footnote).foregroundStyle(Theme.muted)
        }
    }
}

struct HintCard: View {
    let hints: [Hint]
    var tone: Color = Theme.warn
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(hints, id: \.self) { h in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: h.rule == "pause" || h.rule == "pregnancy" ? "hand.raised" : "exclamationmark.circle").foregroundStyle(tone)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.text).font(.callout)
                        if let r = Catalog.rule(h.rule) { Text("Уверенность: \(r.confidence)").font(.caption).foregroundStyle(Theme.muted) }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warnSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ToastView: View {
    let toast: Toast
    let dismiss: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Text(toast.text).font(.callout).foregroundStyle(Theme.paper).lineLimit(2)
            Spacer(minLength: 0)
            if let undo = toast.undo {
                Button("Отменить") { undo(); dismiss() }.font(.callout.bold()).foregroundStyle(Theme.accentSoft)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.ink, in: Capsule())
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

/// Уровень реакции: нет · слабо · средне · сильно.
struct LevelPicker: View {
    let title: String
    @Binding var level: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            Picker(title, selection: Binding(get: { level ?? -1 }, set: { level = $0 < 0 ? nil : $0 })) {
                Text("—").tag(-1)
                ForEach(0..<Catalog.levels.count, id: \.self) { i in Text(Catalog.levels[i]).tag(i) }
            }
            .pickerStyle(.segmented)
        }
    }
}

extension View {
    func card() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.raise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension Date {
    init(dayKey: String) { self = Days.noon(dayKey) }
}
