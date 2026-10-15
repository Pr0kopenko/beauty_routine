import Foundation
import SwiftData

@Model
final class CareEntry {
    var date: Date
    var note: String
    var product: Product?

    init(product: Product, date: Date = .now, note: String = "") {
        self.product = product
        self.date = date
        self.note = note
    }
}
