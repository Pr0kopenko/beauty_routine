import Foundation
import SwiftData

enum ProductKind: String, Codable, CaseIterable, Identifiable {
    case retinol
    case serum
    case supplement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .retinol: "Ретинол"
        case .serum: "Сыворотка"
        case .supplement: "Добавка"
        }
    }

    var symbol: String {
        switch self {
        case .retinol: "moon.stars"
        case .serum: "drop"
        case .supplement: "pills"
        }
    }
}

@Model
final class Product {
    var name: String
    var kind: ProductKind
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CareEntry.product)
    var entries: [CareEntry] = []

    init(name: String, kind: ProductKind, createdAt: Date = .now) {
        self.name = name
        self.kind = kind
        self.createdAt = createdAt
    }

    var lastUsed: Date? {
        entries.map(\.date).max()
    }

    func wasUsed(on day: Date, calendar: Calendar = .current) -> Bool {
        entries.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }
}
