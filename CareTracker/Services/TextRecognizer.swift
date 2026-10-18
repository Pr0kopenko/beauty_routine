import UIKit
import Vision

/// Распознавание текста состава прямо на телефоне (без интернета и без ключа ИИ).
enum TextRecognizer {
    static func text(in image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: " "))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "ru-RU"]
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cg, orientation: CGImagePropertyOrientation(image.imageOrientation))
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch { cont.resume(returning: "") }
            }
        }
    }

    /// Офлайн-распознавание: текст → активы по словарю INCI.
    static func recognize(_ image: UIImage) async -> RecognizedProduct {
        let text = await text(in: image)
        let kbFound = Knowledge.analyze(text)
        var found = Knowledge.coarseActives(kbFound)
        for a in Inci.detect(text).actives where !found.contains(a) { found.append(a) }
        let form = Knowledge.retinoidForm(kbFound) ?? Inci.retinoidForm(text)
        let type = found.contains("spf") ? "spf" : found.contains("supplement") ? "supplement" : "other"
        return RecognizedProduct(isSkincare: true, brand: "", name: "", type: type, actives: found, retinoidForm: found.contains("retinoid") ? (form ?? "retinol") : nil,
                                 strength: "", time: found.contains("retinoid") ? "evening" : found.contains("spf") ? "morning" : "any",
                                 composition: text, confidence: text.count > 40 ? "medium" : "low",
                                 note: text.isEmpty ? "Текст на фото не найден. Сними состав поближе или впиши название." : "Распознала текст на телефоне. Название впиши сама или подключи ИИ.", source: .device)
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
