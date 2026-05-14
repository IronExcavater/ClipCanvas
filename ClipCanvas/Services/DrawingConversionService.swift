import PencilKit
import Vision
import CoreGraphics
import UIKit

enum DrawingConversionService {
    static func recognizeText(in drawing: PKDrawing, size: CGSize) async -> [String] {
        let image = drawing.image(from: CGRect(origin: .zero, size: size), scale: UIScreen.main.scale)
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let texts = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: texts)
            }
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
