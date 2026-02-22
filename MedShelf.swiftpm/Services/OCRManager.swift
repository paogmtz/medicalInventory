import Vision
import UIKit

// MARK: - OCR Errors

/// Errors that can occur during the OCR recognition pipeline.
enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(String)
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image for text recognition."
        case .recognitionFailed(let reason):
            return "Text recognition failed: \(reason)"
        case .noTextFound:
            return "No text was detected in the image."
        }
    }
}

// MARK: - OCR Line

/// A single line of recognized text with its Vision confidence score.
struct OCRLine: Sendable {
    let text: String
    let confidence: Float   // 0.0 - 1.0
}

// MARK: - OCR Result

/// Structured result from the full OCR scan-and-parse pipeline.
struct OCRResult: Sendable {
    let rawText: String
    let suggestedName: String?
    let suggestedDose: String?
    let suggestedForm: MedicineForm?
    let suggestedExpiry: Date?
    let suggestedQuantity: Int?
    let suggestedQuantityUnit: QuantityUnit?
    let confidence: Double
}

// MARK: - OCR Manager

/// Stateless OCR service that wraps Apple Vision's `VNRecognizeTextRequest`.
///
/// - Configured for `.accurate` recognition on bilingual (Spanish + English)
///   pharmaceutical packaging.
/// - All methods are `static` and use `async/await`; Vision work is dispatched
///   to a background queue automatically by `withCheckedThrowingContinuation`.
/// - Fully offline -- no network calls.
struct OCRManager {

    // MARK: - Text Recognition

    /// Recognize text in a `CGImage` using Vision's accurate recognition level.
    ///
    /// The request is configured for bilingual medicine packaging:
    /// - `recognitionLevel = .accurate` for best quality on varied fonts.
    /// - `recognitionLanguages = ["es", "en"]` (Spanish priority for LatAm packaging).
    /// - `usesLanguageCorrection = true` for pharmaceutical term correction.
    /// - `minimumTextHeight = 0.02` to capture fine-print dosage text.
    ///
    /// - Parameter cgImage: The image to perform OCR on. Ideally downsampled
    ///   to ~1600px on the long side for optimal accuracy-to-speed ratio.
    /// - Returns: An array of `OCRLine` values, one per recognized text observation,
    ///   ordered top-to-bottom as they appear in the image.
    /// - Throws: `OCRError.recognitionFailed` if Vision encounters an error.
    static func recognizeText(in cgImage: CGImage) async throws -> [OCRLine] {
        try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            let request = VNRecognizeTextRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                if let error = error {
                    continuation.resume(
                        throwing: OCRError.recognitionFailed(error.localizedDescription)
                    )
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let lines: [OCRLine] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    return OCRLine(
                        text: candidate.string,
                        confidence: candidate.confidence
                    )
                }

                continuation.resume(returning: lines)
            }

            // Configure for bilingual medicine packaging
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es", "en"]
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.02

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: .up,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Full Pipeline

    /// End-to-end pipeline: image -> OCR recognition -> text parsing -> structured result.
    ///
    /// 1. Runs `recognizeText(in:)` to obtain raw OCR lines.
    /// 2. Joins lines and passes to `OCRParser` for dose, form, expiry, and quantity extraction.
    /// 3. Computes an overall confidence score.
    /// 4. Heuristically selects the first OCR line as the suggested product name.
    ///
    /// - Parameter image: A `CGImage` (ideally pre-downsampled to ~1600px).
    /// - Returns: An `OCRResult` with suggested field values and confidence.
    /// - Throws: `OCRError` if recognition fails or yields no text.
    static func scan(image: CGImage) async throws -> OCRResult {
        let lines = try await recognizeText(in: image)

        guard !lines.isEmpty else {
            throw OCRError.noTextFound
        }

        let fullText = lines.map(\.text).joined(separator: "\n")
        let averageConfidence: Float = lines.map(\.confidence).reduce(0, +) / Float(lines.count)

        // Parse structured fields
        let doses = OCRParser.extractDoses(from: fullText)
        let form = OCRParser.extractForm(from: fullText)
        let expiry = OCRParser.extractExpiration(from: fullText)
        let quantity = OCRParser.extractQuantity(from: fullText)

        // Confidence scoring
        let confidence = OCRParser.computeConfidence(
            averageOCRConfidence: averageConfidence,
            hasDose: !doses.isEmpty,
            hasForm: form != nil,
            hasExpiration: expiry != nil,
            hasQuantity: quantity != nil
        )

        // Heuristic: the first recognized line is often the product/brand name
        let suggestedName = lines.first?.text

        // Map parsed quantity unit to the app's QuantityUnit enum
        let suggestedUnit: QuantityUnit? = {
            guard let q = quantity else { return nil }
            let lower = q.unit.lowercased()
            if lower.contains("ml") || lower.contains("l") {
                return .ml
            }
            if lower.contains("g") && !lower.contains("gragea") {
                return .g
            }
            return .pills
        }()

        return OCRResult(
            rawText: fullText,
            suggestedName: suggestedName,
            suggestedDose: doses.first?.rawMatch,
            suggestedForm: form,
            suggestedExpiry: expiry?.date,
            suggestedQuantity: quantity?.count,
            suggestedQuantityUnit: suggestedUnit,
            confidence: confidence
        )
    }
}
