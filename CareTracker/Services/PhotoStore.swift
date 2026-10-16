import UIKit

/// Фото лица и миниатюры средств — файлы на устройстве. В ИИ фото лица не отправляются.
enum PhotoStore {
    static var faces: URL { folder("FacePhotos") }
    static var thumbs: URL { folder("Thumbs") }

    private static func folder(_ name: String) -> URL {
        let dir = Storage.directory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Сохраняет фото лица (до 1600 px) с полной защитой файла. Возвращает id.
    static func saveFace(_ image: UIImage) throws -> String {
        let id = Ids.make()
        let data = image.resized(maxSide: 1600).jpegData(compressionQuality: 0.85) ?? Data()
        try data.write(to: faces.appendingPathComponent("\(id).jpg"), options: [.atomic, .completeFileProtection])
        return id
    }
    static func face(_ id: String) -> UIImage? { UIImage(contentsOfFile: faces.appendingPathComponent("\(id).jpg").path) }
    static func deleteFace(_ id: String) { try? FileManager.default.removeItem(at: faces.appendingPathComponent("\(id).jpg")) }

    /// Квадратная миниатюра средства 240 px.
    static func saveThumb(_ image: UIImage) -> String? {
        let name = "\(Ids.make()).jpg"
        guard let data = image.squareThumb(240).jpegData(compressionQuality: 0.8) else { return nil }
        try? data.write(to: thumbs.appendingPathComponent(name), options: .atomic)
        return name
    }
    static func thumb(_ ref: String?) -> UIImage? {
        guard let ref, !ref.isEmpty else { return nil }
        if ref.hasPrefix("data:"), let comma = ref.firstIndex(of: ","), let data = Data(base64Encoded: String(ref[ref.index(after: comma)...])) {
            return UIImage(data: data) // миниатюра из копии PWA
        }
        return UIImage(contentsOfFile: thumbs.appendingPathComponent(ref).path)
    }

    static func exportFaces(ids: [(id: String, day: String)]) -> [BackupPhoto] {
        ids.compactMap { p in
            guard let data = try? Data(contentsOf: faces.appendingPathComponent("\(p.id).jpg")) else { return nil }
            return BackupPhoto(id: p.id, day: p.day, at: nil, data: "data:image/jpeg;base64," + data.base64EncodedString())
        }
    }
    static func importFaces(_ photos: [BackupPhoto]) {
        for p in photos {
            guard let comma = p.data.firstIndex(of: ","), let data = Data(base64Encoded: String(p.data[p.data.index(after: comma)...])) else { continue }
            try? data.write(to: faces.appendingPathComponent("\(p.id).jpg"), options: [.atomic, .completeFileProtection])
        }
    }
    static func deleteAll() {
        try? FileManager.default.removeItem(at: faces)
        try? FileManager.default.removeItem(at: thumbs)
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
    func squareThumb(_ side: CGFloat) -> UIImage {
        let s = min(size.width, size.height)
        let rect = CGRect(x: (size.width - s) / 2, y: (size.height - s) / 2, width: s, height: s)
        let target = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: target).image { _ in
            draw(in: CGRect(x: -rect.minX * side / s, y: -rect.minY * side / s, width: size.width * side / s, height: size.height * side / s))
        }
    }
}
