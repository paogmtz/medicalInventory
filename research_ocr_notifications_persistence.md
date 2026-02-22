# Research: OCR, Local Notifications & Persistence for Swift Playgrounds

> **Agent R3** -- On-Device OCR + Local Notifications Best Practices Research
> Target: Swift Playgrounds project (offline, no external dependencies)
> Date: 2026-02-21

---

## Part A: On-Device OCR with Apple Vision

### A.1 VNRecognizeTextRequest Best Practices

#### Recognition Level: Fast vs. Accurate

Apple Vision provides two recognition levels through `VNRecognizeTextRequest`:

| Level | Speed | Accuracy | Use Case |
|---|---|---|---|
| `.fast` | ~0.3-0.5s per image | Good for clear, printed text | Quick previews, real-time scanning |
| `.accurate` | ~1-3s per image | Best for varied fonts, angles, low contrast | Final OCR pass on medicine boxes |

**Recommendation for this project**: Use `.accurate` for the primary OCR pass on medicine box photos. The extra processing time (1-3 seconds) is acceptable for a non-real-time workflow where users photograph a box and wait for results.

#### Language Support (English + Spanish)

The `recognitionLanguages` property accepts an array of BCP-47 language codes **in priority order**. For bilingual medicine packaging:

```swift
request.recognitionLanguages = ["es", "en"]
```

Place Spanish first if the primary market is Latin America. The framework processes both languages simultaneously. Supported language codes for `.accurate` level include `"en-US"`, `"es-ES"`, `"es-MX"`, `"fr-FR"`, `"de-DE"`, `"it-IT"`, `"pt-BR"`, and many others.

You can query available languages at runtime:

```swift
let supportedLanguages = try VNRecognizeTextRequest
    .supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision3)
// Returns: ["en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR", ...]
```

#### Language Correction

Enable `usesLanguageCorrection = true` for medicine box text. This applies a language model post-processing step that corrects OCR misreads (e.g., "tab1et" -> "tablet", "cápsu1a" -> "cápsula"). Slight additional processing cost but significantly improves accuracy on pharmaceutical terms.

#### Minimum Text Height

Set `minimumTextHeight` to filter noise. For medicine boxes where you want the primary label text:

```swift
request.minimumTextHeight = 0.02 // 2% of image height -- filters tiny print
```

Adjust upward (0.05-0.1) if you only want large product names, or leave low (0.01-0.02) to capture fine-print dosage information.

#### Performance Characteristics

- **Speed**: `.accurate` takes 1-3s on modern iPads (A12+ chip); `.fast` takes 0.3-0.5s
- **Accuracy**: `.accurate` achieves 95%+ on clean printed text; drops to 85-90% on curved/glossy surfaces
- **Memory**: Each request uses ~50-100MB temporarily; release `VNImageRequestHandler` after use
- **Threading**: `VNImageRequestHandler.perform()` is synchronous and should run on a background queue

#### Image Preprocessing Tips

1. **Resolution**: Aim for 1200-2000px on the long side. Below 800px, small text becomes unreadable. Above 3000px, processing time increases without accuracy gains.
2. **Contrast**: Medicine boxes on white backgrounds work well. For glossy packaging, avoid flash glare.
3. **Orientation**: Set the image orientation hint on `VNImageRequestHandler`:
   ```swift
   let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
   ```
   If the device orientation is known, pass it explicitly. Vision can handle rotated text, but providing the correct orientation improves speed and accuracy.
4. **Color Space**: Convert to grayscale before OCR only if the original has very low contrast. For most medicine boxes with high-contrast printing, the original color image works fine.

---

### A.2 Image Acquisition in Swift Playgrounds

#### PhotosPicker (Recommended Primary Approach)

`PhotosPicker` from PhotosUI is a pure SwiftUI component that works natively in Swift Playgrounds without UIKit wrapping. It is available on iOS 16+ / iPadOS 16+.

```swift
import PhotosUI
import SwiftUI

struct ImagePickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label("Select Medicine Photo", systemImage: "photo.on.rectangle")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                }
            }
        }
    }
}
```

**No special permissions needed** for `PhotosPicker` -- it uses an out-of-process picker, so the app never directly accesses the photo library. No `NSPhotoLibraryUsageDescription` required.

#### Camera Capture (iPad Only)

Camera access in Swift Playgrounds is possible but requires UIKit wrapping via `UIViewControllerRepresentable`. The camera is **not available** on Mac (Mac Catalyst or macOS). On iPad, it is available starting iPadOS 16+.

**Capability declaration required**: Add `NSCameraUsageDescription` to the app's Info.plist or app capabilities in Swift Playgrounds.

For Swift Playgrounds, you request this in the project settings (Capabilities editor), or via `Package.swift`:

```swift
// In Package.swift, within .iOSApplication:
additionalInfoPlistContentFilePath: "AppInfo.plist"
```

Then in `AppInfo.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to photograph medicine boxes for inventory</string>
```

A lightweight camera picker using `UIImagePickerController`:

```swift
import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

Check availability before presenting:

```swift
let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
```

#### Image Downscaling Strategy (Target ~1600px Long Side)

Use **ImageIO / CGImageSource downsampling** for memory-efficient resizing. This is Apple's recommended approach -- it avoids fully decoding the original image into memory.

```swift
import ImageIO
import UIKit

enum ImageProcessing {

    /// Downsample an image to a maximum pixel dimension on its longest side.
    /// Uses ImageIO for memory-efficient processing (no full decode of original).
    static func downsample(imageData: Data, maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(imageData as CFData, options as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary)
    }

    /// Create a full-size image suitable for OCR (~1600px long side)
    static func prepareForOCR(imageData: Data) -> CGImage? {
        downsample(imageData: imageData, maxPixelSize: 1600)
    }

    /// Create a thumbnail for list views (256-512px)
    static func createThumbnail(imageData: Data, size: CGFloat = 512) -> CGImage? {
        downsample(imageData: imageData, maxPixelSize: size)
    }

    /// Compress a UIImage to JPEG data for storage
    static func compressForStorage(image: UIImage, quality: CGFloat = 0.7) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}
```

#### Thumbnail Generation (256-512px)

Use the same `downsample` function with a smaller `maxPixelSize`. Store thumbnails separately to avoid reprocessing:

- **List view thumbnails**: 256px -- fast loading, small file (~20-40KB at JPEG 0.7)
- **Detail view thumbnails**: 512px -- decent quality, moderate file (~60-120KB at JPEG 0.7)
- **OCR source**: 1600px -- full detail for text recognition (~200-400KB at JPEG 0.8)

#### JPEG Compression for Storage

```swift
// For thumbnails: higher compression is acceptable
let thumbnailData = image.jpegData(compressionQuality: 0.6) // ~30-60KB

// For OCR source: preserve more detail
let ocrData = image.jpegData(compressionQuality: 0.8) // ~200-400KB

// For original archival (optional): balance size and quality
let archiveData = image.jpegData(compressionQuality: 0.7) // ~150-300KB
```

---

### A.3 Text Parsing Heuristics for Medicine Boxes

#### Dose Extraction Patterns

Medicine doses typically appear as a numeric value followed by a unit. Support both integer and decimal values:

```swift
import Foundation

struct DoseInfo {
    let value: String    // e.g., "500", "0.25"
    let unit: String     // e.g., "mg", "mcg"
    let rawMatch: String // e.g., "500 mg"
}

/// Extract dose information from OCR text.
/// Matches patterns like: "500 mg", "0.25 mg", "10 mcg/mL", "100 mg/5 mL"
func extractDoses(from text: String) -> [DoseInfo] {
    // Pattern: number (optional decimal) + optional space + unit
    // Units: mg, mcg, g, kg, mL, L, IU, UI, mcg/mL, mg/mL, mg/5mL, etc.
    let pattern = #"(\d+(?:[.,]\d+)?)\s*(mg|mcg|µg|g|kg|m[lL]|[lL]|IU|UI|mEq)(?:\s*/\s*(\d*\s*m?[lL]))?"#

    var results: [DoseInfo] = []

    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let valueRange = Range(match.range(at: 1), in: text),
               let unitRange = Range(match.range(at: 2), in: text),
               let fullRange = Range(match.range, in: text) {
                let value = String(text[valueRange])
                let unit = String(text[unitRange]).lowercased()
                let rawMatch = String(text[fullRange])
                results.append(DoseInfo(value: value, unit: unit, rawMatch: rawMatch))
            }
        }
    }
    return results
}
```

#### Form Detection Patterns (English + Spanish)

```swift
struct FormInfo {
    let form: String       // normalized: "tablet", "capsule", "syrup", etc.
    let rawMatch: String
}

/// Detect pharmaceutical form from OCR text (bilingual EN/ES).
func extractForm(from text: String) -> FormInfo? {
    // Map of regex patterns to normalized form names
    let formPatterns: [(pattern: String, form: String)] = [
        // English forms
        (#"\b(?:tablets?|tabs?)\b"#, "tablet"),
        (#"\b(?:capsules?|caps?)\b"#, "capsule"),
        (#"\b(?:syrups?)\b"#, "syrup"),
        (#"\b(?:creams?)\b"#, "cream"),
        (#"\b(?:ointments?)\b"#, "ointment"),
        (#"\b(?:drops?|gtt)\b"#, "drops"),
        (#"\b(?:solution|soln?)\b"#, "solution"),
        (#"\b(?:suspension|susp)\b"#, "suspension"),
        (#"\b(?:injection|inj)\b"#, "injection"),
        (#"\b(?:patch(?:es)?)\b"#, "patch"),
        (#"\b(?:gel)\b"#, "gel"),
        (#"\b(?:spray)\b"#, "spray"),
        (#"\b(?:inhaler)\b"#, "inhaler"),
        (#"\b(?:suppository|suppositories)\b"#, "suppository"),
        (#"\b(?:powder)\b"#, "powder"),
        (#"\b(?:lozenges?)\b"#, "lozenge"),

        // Spanish forms
        (#"\b(?:comprimidos?|tabletas?)\b"#, "tablet"),
        (#"\b(?:cápsulas?|capsulas?)\b"#, "capsule"),
        (#"\b(?:jarabes?|sirope)\b"#, "syrup"),
        (#"\b(?:cremas?)\b"#, "cream"),
        (#"\b(?:pomadas?|ungüentos?)\b"#, "ointment"),
        (#"\b(?:gotas)\b"#, "drops"),
        (#"\b(?:solución|solucion)\b"#, "solution"),
        (#"\b(?:suspensión|suspension)\b"#, "suspension"),
        (#"\b(?:inyección|inyeccion|inyectable)\b"#, "injection"),
        (#"\b(?:parches?)\b"#, "patch"),
        (#"\b(?:sobres?)\b"#, "powder"),         // "sobre" = sachet/powder packet
        (#"\b(?:supositorio)\b"#, "suppository"),
        (#"\b(?:aerosol|inhalador)\b"#, "inhaler"),
        (#"\b(?:óvulos?|ovulos?)\b"#, "ovule"),
        (#"\b(?:ampolla|ampollas)\b"#, "ampoule"),
        (#"\b(?:pastillas?)\b"#, "tablet"),       // colloquial for tablet
        (#"\b(?:grageas?)\b"#, "dragee"),         // coated tablet
    ]

    let lowered = text.lowercased()

    for (pattern, form) in formPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)),
           let range = Range(match.range, in: lowered) {
            return FormInfo(form: form, rawMatch: String(lowered[range]))
        }
    }
    return nil
}
```

#### Expiration Date Patterns (Bilingual)

Expiration dates on medicine packaging use various labels and date formats. Key labels:

| Language | Labels |
|---|---|
| English | EXP, EXP DATE, EXPIRY, EXPIRES, USE BY, BEST BEFORE |
| Spanish | CAD, CADUCIDAD, FECHA DE CADUCIDAD, VENCE, VTO, VENCIMIENTO, FV, FECHA DE VENCIMIENTO, VAL, VALIDEZ |

Date formats commonly seen on packaging:

| Format | Example | Regex |
|---|---|---|
| MM/YYYY | 03/2027 | `\d{2}/\d{4}` |
| dd/MM/YYYY | 15/03/2027 | `\d{2}/\d{2}/\d{4}` |
| YYYY-MM-DD | 2027-03-15 | `\d{4}-\d{2}-\d{2}` |
| MMM YYYY | MAR 2027 | `[A-Z]{3}\s*\d{4}` |
| MM-YYYY | 03-2027 | `\d{2}-\d{4}` |
| MM.YYYY | 03.2027 | `\d{2}\.\d{4}` |
| dd.MM.YYYY | 15.03.2027 | `\d{2}\.\d{2}\.\d{4}` |

```swift
struct ExpirationInfo {
    let label: String       // e.g., "EXP", "CAD", "VENCE"
    let dateString: String  // e.g., "03/2027"
    let parsedDate: Date?   // Parsed as the last day of the month
    let rawMatch: String
}

/// Extract expiration dates from OCR text (bilingual EN/ES).
func extractExpirationDate(from text: String) -> ExpirationInfo? {
    // Label patterns (English + Spanish)
    let labelPattern = #"(?:EXP(?:IRY|IRES)?\.?\s*(?:DATE)?|USE\s*BY|BEST\s*BEFORE|CAD(?:UCIDAD)?|FECHA\s*(?:DE\s*)?(?:CADUCIDAD|VENCIMIENTO|EXPIRACI[OÓ]N)|VENCE|VTO\.?|VENCIMIENTO|FV|VAL(?:IDEZ)?)"#

    // Date patterns (multiple formats)
    let datePattern = #"(\d{1,2})\s*[/\.\-]\s*(\d{1,2})\s*[/\.\-]\s*(\d{2,4})|(\d{1,2})\s*[/\.\-]\s*(\d{4})|(\d{4})\s*[/\.\-]\s*(\d{1,2})\s*[/\.\-]\s*(\d{1,2})|([A-Za-z]{3,})\s*[/\.\-\s]\s*(\d{4})"#

    // Combined: label followed by optional separator, then date
    let combinedPattern = "(\(labelPattern))[:\\s./\\-]*(\(datePattern))"

    guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: [.caseInsensitive]) else {
        return nil
    }

    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          let fullRange = Range(match.range, in: text) else {
        return nil
    }

    let rawMatch = String(text[fullRange])

    // Extract the label portion
    var label = ""
    if let labelRange = Range(match.range(at: 1), in: text) {
        label = String(text[labelRange]).trimmingCharacters(in: .whitespaces)
    }

    // Extract the date portion (everything after the label)
    let dateString = rawMatch
        .replacingOccurrences(of: label, with: "")
        .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":.-")))

    let parsedDate = parseExpirationDate(dateString)

    return ExpirationInfo(
        label: label,
        dateString: dateString,
        parsedDate: parsedDate,
        rawMatch: rawMatch
    )
}

/// Parse various date formats into a Date (last day of the expiration month).
func parseExpirationDate(_ string: String) -> Date? {
    let formatters: [(String, String)] = [
        ("dd/MM/yyyy", #"^\d{1,2}/\d{1,2}/\d{4}$"#),
        ("MM/yyyy", #"^\d{1,2}/\d{4}$"#),
        ("yyyy-MM-dd", #"^\d{4}-\d{1,2}-\d{1,2}$"#),
        ("dd.MM.yyyy", #"^\d{1,2}\.\d{1,2}\.\d{4}$"#),
        ("MM.yyyy", #"^\d{1,2}\.\d{4}$"#),
        ("MM-yyyy", #"^\d{1,2}-\d{4}$"#),
        ("dd-MM-yyyy", #"^\d{1,2}-\d{1,2}-\d{4}$"#),
    ]

    let cleaned = string.trimmingCharacters(in: .whitespaces)

    for (format, pattern) in formatters {
        if cleaned.range(of: pattern, options: .regularExpression) != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: cleaned) {
                // For MM/yyyy formats, return the last day of that month
                if !format.contains("dd") {
                    let calendar = Calendar.current
                    if let lastDay = calendar.date(
                        byAdding: DateComponents(month: 1, day: -1), to: date
                    ) {
                        return lastDay
                    }
                }
                return date
            }
        }
    }

    // Try month-name formats: "MAR 2027", "March 2027", "Marzo 2027"
    let monthNamePattern = #"^([A-Za-zÁÉÍÓÚáéíóú]+)\s*[/\-\.\s]\s*(\d{4})$"#
    if let regex = try? NSRegularExpression(pattern: monthNamePattern),
       let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
       let monthRange = Range(match.range(at: 1), in: cleaned),
       let yearRange = Range(match.range(at: 2), in: cleaned) {

        let monthStr = String(cleaned[monthRange])
        let yearStr = String(cleaned[yearRange])

        // Try English and Spanish month parsing
        for localeId in ["en_US_POSIX", "es_ES"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: localeId)

            // Try abbreviated month (MAR, ENE)
            formatter.dateFormat = "MMM yyyy"
            if let date = formatter.date(from: "\(monthStr) \(yearStr)") {
                let calendar = Calendar.current
                return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: date)
            }

            // Try full month name (March, Marzo)
            formatter.dateFormat = "MMMM yyyy"
            if let date = formatter.date(from: "\(monthStr) \(yearStr)") {
                let calendar = Calendar.current
                return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: date)
            }
        }
    }

    return nil
}
```

#### Quantity Patterns (English + Spanish)

```swift
struct QuantityInfo {
    let count: String    // e.g., "30", "120"
    let unit: String     // e.g., "tablets", "mL"
    let rawMatch: String
}

/// Extract quantity/count info from OCR text (bilingual EN/ES).
func extractQuantity(from text: String) -> [QuantityInfo] {
    let pattern = #"(\d+)\s*(tablets?|tabs?|capsules?|caps?|pills?|sachets?|ampoules?|vials?|mL|ml|L|l|g|mg|pieces?|units?|comprimidos?|tabletas?|cápsulas?|capsulas?|sobres?|ampollas?|grageas?|pastillas?|unidades?|piezas?)"#

    var results: [QuantityInfo] = []

    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let countRange = Range(match.range(at: 1), in: text),
               let unitRange = Range(match.range(at: 2), in: text),
               let fullRange = Range(match.range, in: text) {
                results.append(QuantityInfo(
                    count: String(text[countRange]),
                    unit: String(text[unitRange]),
                    rawMatch: String(text[fullRange])
                ))
            }
        }
    }
    return results
}
```

#### Confidence Scoring Approach

Not all OCR results are equally reliable. Assign confidence based on multiple signals:

```swift
struct ParsedMedicineInfo {
    var name: String?
    var doses: [DoseInfo]
    var form: FormInfo?
    var expirationDate: ExpirationInfo?
    var quantities: [QuantityInfo]
    var ocrConfidence: Float       // From Vision (0.0 - 1.0)
    var parseConfidence: Float     // From heuristic scoring (0.0 - 1.0)
}

/// Calculate a parse confidence score based on how many fields were extracted.
func calculateParseConfidence(
    ocrConfidence: Float,
    hasDose: Bool,
    hasForm: Bool,
    hasExpiration: Bool,
    hasQuantity: Bool
) -> Float {
    var score: Float = ocrConfidence * 0.4  // 40% weight from OCR confidence

    // Each successfully parsed field adds to confidence
    if hasDose       { score += 0.15 }
    if hasForm       { score += 0.15 }
    if hasExpiration  { score += 0.20 }
    if hasQuantity   { score += 0.10 }

    return min(score, 1.0)
}
```

**Confidence thresholds for UI feedback**:
- `>= 0.8`: High confidence -- show green checkmark, auto-fill fields
- `0.5 - 0.8`: Medium confidence -- show yellow warning, allow user to confirm/edit
- `< 0.5`: Low confidence -- show orange alert, require manual entry

---

### A.4 Complete Code Examples

#### Complete VNRecognizeTextRequest Setup

```swift
import Vision
import UIKit

/// Perform OCR on a UIImage and return recognized text lines with confidence scores.
func performOCR(on image: UIImage) async throws -> [(text: String, confidence: Float)] {
    guard let cgImage = image.cgImage else {
        throw OCRError.invalidImage
    }

    return try await withCheckedThrowingContinuation { continuation in
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                continuation.resume(returning: [])
                return
            }

            let results: [(String, Float)] = observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }
                return (candidate.string, candidate.confidence)
            }

            continuation.resume(returning: results)
        }

        // Configure for bilingual medicine box text
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es", "en"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image for text recognition."
        case .recognitionFailed(let reason):
            return "Text recognition failed: \(reason)"
        }
    }
}
```

#### Image Preprocessing Pipeline

```swift
import UIKit
import ImageIO

/// Full pipeline: acquire image data -> downscale for OCR -> create thumbnail -> store both.
struct ImagePipeline {

    struct ProcessedImage {
        let ocrImage: CGImage       // ~1600px for OCR
        let thumbnail: CGImage      // ~512px for UI
        let ocrJPEGData: Data       // Compressed OCR image
        let thumbnailJPEGData: Data // Compressed thumbnail
    }

    /// Process raw image data from PhotosPicker or camera into OCR and thumbnail versions.
    static func process(imageData: Data) -> ProcessedImage? {
        guard let ocrImage = ImageProcessing.downsample(imageData: imageData, maxPixelSize: 1600),
              let thumbnail = ImageProcessing.downsample(imageData: imageData, maxPixelSize: 512) else {
            return nil
        }

        let ocrUIImage = UIImage(cgImage: ocrImage)
        let thumbUIImage = UIImage(cgImage: thumbnail)

        guard let ocrData = ocrUIImage.jpegData(compressionQuality: 0.8),
              let thumbData = thumbUIImage.jpegData(compressionQuality: 0.6) else {
            return nil
        }

        return ProcessedImage(
            ocrImage: ocrImage,
            thumbnail: thumbnail,
            ocrJPEGData: ocrData,
            thumbnailJPEGData: thumbData
        )
    }
}
```

#### Full Parsing Pipeline

```swift
/// Parse all medicine information from OCR results.
struct MedicineOCRParser {

    struct MedicineParseResult {
        let allText: String
        let doses: [DoseInfo]
        let form: FormInfo?
        let expirationDate: ExpirationInfo?
        let quantities: [QuantityInfo]
        let averageOCRConfidence: Float
        let parseConfidence: Float
    }

    static func parse(ocrResults: [(text: String, confidence: Float)]) -> MedicineParseResult {
        let fullText = ocrResults.map(\.text).joined(separator: "\n")
        let avgConfidence = ocrResults.isEmpty ? 0 :
            ocrResults.map(\.confidence).reduce(0, +) / Float(ocrResults.count)

        let doses = extractDoses(from: fullText)
        let form = extractForm(from: fullText)
        let expiration = extractExpirationDate(from: fullText)
        let quantities = extractQuantity(from: fullText)

        let parseConf = calculateParseConfidence(
            ocrConfidence: avgConfidence,
            hasDose: !doses.isEmpty,
            hasForm: form != nil,
            hasExpiration: expiration != nil,
            hasQuantity: !quantities.isEmpty
        )

        return MedicineParseResult(
            allText: fullText,
            doses: doses,
            form: form,
            expirationDate: expiration,
            quantities: quantities,
            averageOCRConfidence: avgConfidence,
            parseConfidence: parseConf
        )
    }
}
```

#### PhotosPicker Integration in SwiftUI (Complete View)

```swift
import SwiftUI
import PhotosUI

struct MedicineScanView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var parseResult: MedicineOCRParser.MedicineParseResult?
    @State private var isProcessing = false
    @State private var showCamera = false
    @State private var errorMessage: String?

    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image display
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    } else {
                        placeholderView
                    }

                    // Action buttons
                    HStack(spacing: 16) {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images
                        ) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if cameraAvailable {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Camera", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    // Processing indicator
                    if isProcessing {
                        ProgressView("Analyzing medicine box...")
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    // Results
                    if let result = parseResult {
                        resultsView(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Medicine")
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $capturedImage)
            }
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadFromPicker(newItem) }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage {
                    Task { await processImage(image) }
                }
            }
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .frame(height: 200)
            .overlay {
                VStack {
                    Image(systemName: "pills")
                        .font(.largeTitle)
                    Text("Select or capture a medicine box photo")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    private func resultsView(_ result: MedicineOCRParser.MedicineParseResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            confidenceBadge(result.parseConfidence)

            if !result.doses.isEmpty {
                LabeledContent("Dose") {
                    Text(result.doses.map(\.rawMatch).joined(separator: ", "))
                }
            }
            if let form = result.form {
                LabeledContent("Form") {
                    Text(form.form.capitalized)
                }
            }
            if let exp = result.expirationDate {
                LabeledContent("Expires") {
                    Text(exp.dateString)
                }
            }
            if !result.quantities.isEmpty {
                LabeledContent("Quantity") {
                    Text(result.quantities.map(\.rawMatch).joined(separator: ", "))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func confidenceBadge(_ confidence: Float) -> some View {
        HStack {
            Circle()
                .fill(confidence >= 0.8 ? .green : confidence >= 0.5 ? .yellow : .orange)
                .frame(width: 10, height: 10)
            Text("Confidence: \(Int(confidence * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func loadFromPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                capturedImage = image
            }
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
        }
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let ocrResults = try await performOCR(on: image)
            parseResult = MedicineOCRParser.parse(ocrResults: ocrResults)
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
        }
    }
}
```

---

## Part B: Local Notifications

### B.1 UNUserNotificationCenter Setup

#### Permission Request Flow

Notifications require explicit user permission. Request it at a meaningful moment (e.g., when the user first creates a reminder), not at app launch.

```swift
import UserNotifications

actor NotificationManager {
    static let shared = NotificationManager()

    private var isAuthorized = false

    /// Request notification permission. Returns true if granted.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("Notification permission error: \(error)")
            isAuthorized = false
            return false
        }
    }

    /// Check current authorization status without prompting.
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        return settings.authorizationStatus
    }
}
```

#### Scheduling Medication Reminders

Use `UNCalendarNotificationTrigger` for time-based medication reminders. Each reminder gets a unique identifier based on the medicine ID and schedule, enabling targeted cancellation.

```swift
extension NotificationManager {

    struct MedicationReminder {
        let medicineId: String
        let medicineName: String
        let dosage: String
        let hour: Int          // 0-23
        let minute: Int        // 0-59
        let weekdays: [Int]?   // nil = every day, or [1...7] where 1=Sunday
    }

    /// Schedule notifications for a medication reminder using a rolling 7-day window.
    func scheduleReminder(_ reminder: MedicationReminder) async throws {
        let center = UNUserNotificationCenter.current()

        // Remove any existing notifications for this medicine
        let existingIds = (0..<7).map { day in
            "\(reminder.medicineId)-day\(day)"
        }
        center.removePendingNotificationRequests(withIdentifiers: existingIds)

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.body = "Time to take \(reminder.medicineName) (\(reminder.dosage))"
        content.sound = .default
        content.categoryIdentifier = "MEDICATION_REMINDER"
        content.userInfo = ["medicineId": reminder.medicineId]

        // Schedule for next 7 days
        let calendar = Calendar.current
        let today = Date()

        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: targetDate)

            // Skip if weekday filtering is active and this day is not included
            if let allowedDays = reminder.weekdays, !allowedDays.contains(weekday) {
                continue
            }

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false  // Non-repeating; we reschedule weekly
            )

            let request = UNNotificationRequest(
                identifier: "\(reminder.medicineId)-day\(dayOffset)",
                content: content,
                trigger: trigger
            )

            try await center.add(request)
        }
    }

    /// Cancel all notifications for a specific medicine.
    func cancelReminders(for medicineId: String) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<7).map { "\(medicineId)-day\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Reschedule all active reminders (call weekly or when reminders change).
    func rescheduleAll(reminders: [MedicationReminder]) async throws {
        // Clear all pending
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Reschedule each
        for reminder in reminders {
            try await scheduleReminder(reminder)
        }
    }
}
```

#### Rolling Window Approach (Next 7 Days)

**Why a rolling window?** iOS has a limit of 64 scheduled local notifications per app. For a medication inventory app, users may have multiple medicines with multiple daily doses. A 7-day window keeps the count manageable:

- 5 medicines x 2 doses/day x 7 days = 70 notifications (over limit)
- 5 medicines x 2 doses/day x 5 days = 50 notifications (safe)

**Recommendation**: Use a 5-7 day window. Reschedule when:
1. The app enters the foreground (via `scenePhase` or `UIApplication.willEnterForegroundNotification`)
2. A reminder is added, modified, or deleted
3. Weekly via a background task (if available)

```swift
import SwiftUI

@main
struct MedicalInventoryApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshNotifications()
                }
            }
        }
    }

    private func refreshNotifications() async {
        let status = await NotificationManager.shared.checkPermissionStatus()
        guard status == .authorized else { return }

        // Load reminders from persistence and reschedule
        let reminders = PersistenceManager.shared.loadReminders()
        try? await NotificationManager.shared.rescheduleAll(reminders: reminders)
    }
}
```

---

### B.2 Graceful Degradation Without Permission

#### Checking Permission Status

```swift
enum NotificationPermissionState {
    case notDetermined  // Never asked
    case authorized     // Granted
    case denied         // Denied (user must go to Settings)
    case provisional    // Quiet notifications
}

extension NotificationManager {
    func getPermissionState() async -> NotificationPermissionState {
        let status = await checkPermissionStatus()
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .provisional:   return .provisional
        @unknown default:    return .denied
        }
    }
}
```

#### In-App Reminder UI as Fallback

When notifications are denied or unavailable, provide an in-app reminder system:

```swift
import SwiftUI

struct InAppReminderBanner: View {
    let medicineName: String
    let dosage: String
    let scheduledTime: Date
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack {
                Image(systemName: "pill.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminder: \(medicineName)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(dosage) -- \(scheduledTime, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    withAnimation { isDismissed = true }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
```

#### Prompting User Without Being Annoying

Follow a respectful permission flow:

```swift
struct NotificationPermissionView: View {
    @State private var permissionState: NotificationPermissionState = .notDetermined
    @State private var hasAskedThisSession = false

    var body: some View {
        Group {
            switch permissionState {
            case .notDetermined:
                // First time: explain why, then ask
                if !hasAskedThisSession {
                    prePermissionPrompt
                }

            case .denied:
                // Don't ask again -- show a subtle, non-blocking hint
                deniedHint

            case .authorized, .provisional:
                // All good -- show nothing
                EmptyView()
            }
        }
        .task {
            permissionState = await NotificationManager.shared.getPermissionState()
        }
    }

    private var prePermissionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            Text("Never miss a dose")
                .font(.headline)

            Text("Enable notifications to receive medication reminders at the right time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Enable Reminders") {
                Task {
                    let granted = await NotificationManager.shared.requestPermission()
                    permissionState = granted ? .authorized : .denied
                    hasAskedThisSession = true
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Not now") {
                hasAskedThisSession = true
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var deniedHint: some View {
        // Show only once per session, non-blocking
        HStack {
            Image(systemName: "bell.slash")
                .foregroundStyle(.secondary)
            Text("Notifications are off. Enable in Settings for medication reminders.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal)
    }
}
```

---

### B.3 Notification Code Examples

#### Complete Notification Scheduling Example

```swift
// Usage from a view model or view:

func setupMedicationReminder(
    medicineId: String,
    name: String,
    dosage: String,
    times: [(hour: Int, minute: Int)],  // e.g., [(8, 0), (20, 0)] for 8 AM and 8 PM
    days: [Int]? = nil                   // nil = every day
) async {
    // Step 1: Ensure permission
    let state = await NotificationManager.shared.getPermissionState()

    switch state {
    case .notDetermined:
        let granted = await NotificationManager.shared.requestPermission()
        if !granted {
            // Fall back to in-app reminders
            enableInAppReminders(for: medicineId)
            return
        }

    case .denied:
        // Use in-app reminders silently
        enableInAppReminders(for: medicineId)
        return

    case .authorized, .provisional:
        break // Continue to schedule
    }

    // Step 2: Schedule for each time
    for (index, time) in times.enumerated() {
        let reminder = NotificationManager.MedicationReminder(
            medicineId: "\(medicineId)-t\(index)",
            medicineName: name,
            dosage: dosage,
            hour: time.hour,
            minute: time.minute,
            weekdays: days
        )
        try? await NotificationManager.shared.scheduleReminder(reminder)
    }
}

func enableInAppReminders(for medicineId: String) {
    // Store flag that this medicine uses in-app reminders
    // The app will check and display banners when active
    UserDefaults.standard.set(true, forKey: "inAppReminder-\(medicineId)")
}
```

#### Permission Handling (Complete Flow)

```swift
/// Observable object to track notification state across the app.
@Observable
class NotificationState {
    var isAuthorized = false
    var isDenied = false
    var hasBeenAsked = false

    func refresh() async {
        let state = await NotificationManager.shared.getPermissionState()
        isAuthorized = (state == .authorized || state == .provisional)
        isDenied = (state == .denied)
        hasBeenAsked = (state != .notDetermined)
    }

    func requestIfNeeded() async -> Bool {
        if !hasBeenAsked {
            let granted = await NotificationManager.shared.requestPermission()
            await refresh()
            return granted
        }
        return isAuthorized
    }
}
```

#### In-App Fallback Timer System

```swift
import SwiftUI

/// Manages in-app reminders when push notifications are unavailable.
@Observable
class InAppReminderManager {
    struct PendingReminder: Identifiable {
        let id: String
        let medicineName: String
        let dosage: String
        let scheduledTime: Date
    }

    var activeReminders: [PendingReminder] = []
    private var timer: Timer?

    func startMonitoring(reminders: [NotificationManager.MedicationReminder]) {
        timer?.invalidate()
        // Check every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkReminders(reminders)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkReminders(_ reminders: [NotificationManager.MedicationReminder]) {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        for reminder in reminders {
            // Trigger if within 1 minute of scheduled time
            if reminder.hour == currentHour && abs(reminder.minute - currentMinute) <= 1 {
                let alreadyActive = activeReminders.contains { $0.id == reminder.medicineId }
                if !alreadyActive {
                    activeReminders.append(PendingReminder(
                        id: reminder.medicineId,
                        medicineName: reminder.medicineName,
                        dosage: reminder.dosage,
                        scheduledTime: now
                    ))
                }
            }
        }
    }

    func dismiss(_ reminderId: String) {
        activeReminders.removeAll { $0.id == reminderId }
    }
}

/// View that overlays in-app reminders at the top of the screen.
struct InAppReminderOverlay: View {
    @Bindable var manager: InAppReminderManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(manager.activeReminders) { reminder in
                InAppReminderBanner(
                    medicineName: reminder.medicineName,
                    dosage: reminder.dosage,
                    scheduledTime: reminder.scheduledTime
                )
            }
        }
        .animation(.spring, value: manager.activeReminders.count)
    }
}
```

---

## Part C: Persistence in Swift Playgrounds

### C.1 JSON + FileManager Approach

#### Design Principles for Swift Playgrounds Persistence

1. **No external dependencies**: Use only Foundation (`JSONEncoder`, `JSONDecoder`, `FileManager`).
2. **Codable models**: All data models conform to `Codable` for automatic JSON serialization.
3. **Documents directory**: Primary storage location; persists across app launches and is backed up.
4. **Separate files per entity type**: `medicines.json`, `reminders.json`, etc. Avoids monolithic files.
5. **Images stored as separate JPEG files**: Referenced by filename in JSON models. Never embed base64 in JSON.
6. **Thread safety**: Use an actor for all file operations to prevent data races.

#### File Paths

```swift
import Foundation

enum StoragePath {
    static let documents: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    static let imagesDirectory: URL = {
        let url = documents.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let thumbnailsDirectory: URL = {
        let url = documents.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func jsonFile(named name: String) -> URL {
        documents.appendingPathComponent("\(name).json")
    }

    static func imageFile(id: String) -> URL {
        imagesDirectory.appendingPathComponent("\(id).jpg")
    }

    static func thumbnailFile(id: String) -> URL {
        thumbnailsDirectory.appendingPathComponent("\(id)_thumb.jpg")
    }
}
```

#### Thread Safety with Actor

All file I/O is wrapped in an actor to prevent concurrent access issues:

```swift
actor JSONStore {
    static let shared = JSONStore()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Save a Codable value to a JSON file.
    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let url = StoragePath.jsonFile(named: filename)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    /// Load a Codable value from a JSON file.
    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let url = StoragePath.jsonFile(named: filename)
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    /// Load or return a default value if file doesn't exist.
    func loadOrDefault<T: Decodable>(_ type: T.Type, from filename: String, default defaultValue: T) -> T {
        do {
            return try load(type, from: filename)
        } catch {
            return defaultValue
        }
    }

    /// Delete a JSON file.
    func delete(filename: String) throws {
        let url = StoragePath.jsonFile(named: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Check if a JSON file exists.
    func exists(filename: String) -> Bool {
        let url = StoragePath.jsonFile(named: filename)
        return FileManager.default.fileExists(atPath: url.path)
    }
}
```

---

### C.2 Code Examples

#### Generic JSON Persistence Manager

```swift
/// Type-safe persistence manager for any Codable collection.
actor PersistenceManager {
    static let shared = PersistenceManager()

    // MARK: - Medicines

    private let medicinesFile = "medicines"

    func saveMedicines(_ medicines: [Medicine]) throws {
        try JSONStore.shared.save(medicines, to: medicinesFile)
    }

    func loadMedicines() -> [Medicine] {
        JSONStore.shared.loadOrDefault([Medicine].self, from: medicinesFile, default: [])
    }

    func addMedicine(_ medicine: Medicine) throws {
        var medicines = loadMedicines()
        medicines.append(medicine)
        try saveMedicines(medicines)
    }

    func updateMedicine(_ medicine: Medicine) throws {
        var medicines = loadMedicines()
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            medicines[index] = medicine
            try saveMedicines(medicines)
        }
    }

    func deleteMedicine(id: String) throws {
        var medicines = loadMedicines()
        medicines.removeAll { $0.id == id }
        try saveMedicines(medicines)

        // Also delete associated images
        try ImageStore.shared.deleteImages(for: id)
    }

    // MARK: - Reminders

    private let remindersFile = "reminders"

    func saveReminders(_ reminders: [NotificationManager.MedicationReminder]) throws {
        try JSONStore.shared.save(reminders, to: remindersFile)
    }

    func loadReminders() -> [NotificationManager.MedicationReminder] {
        JSONStore.shared.loadOrDefault(
            [NotificationManager.MedicationReminder].self,
            from: remindersFile,
            default: []
        )
    }
}

// Make MedicationReminder Codable for persistence
extension NotificationManager.MedicationReminder: Codable {}
```

#### Example Medicine Model

```swift
import Foundation

struct Medicine: Identifiable, Codable {
    let id: String
    var name: String
    var dose: String              // e.g., "500 mg"
    var form: String              // e.g., "tablet"
    var quantity: Int              // e.g., 30
    var quantityUnit: String      // e.g., "tablets"
    var expirationDate: Date?
    var notes: String
    var imageFilename: String?    // Reference to JPEG in Images/
    var thumbnailFilename: String? // Reference to JPEG in Thumbnails/
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        dose: String = "",
        form: String = "",
        quantity: Int = 0,
        quantityUnit: String = "",
        expirationDate: Date? = nil,
        notes: String = ""
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.dose = dose
        self.form = form
        self.quantity = quantity
        self.quantityUnit = quantityUnit
        self.expirationDate = expirationDate
        self.notes = notes
        self.imageFilename = nil
        self.thumbnailFilename = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

#### Image Storage / Retrieval Helper

```swift
import UIKit

actor ImageStore {
    static let shared = ImageStore()

    /// Save OCR image and thumbnail for a medicine.
    /// Returns (imageFilename, thumbnailFilename).
    func saveImages(
        ocrImageData: Data,
        thumbnailData: Data,
        for medicineId: String
    ) throws -> (String, String) {
        let imageFilename = "\(medicineId).jpg"
        let thumbFilename = "\(medicineId)_thumb.jpg"

        let imageURL = StoragePath.imageFile(id: medicineId)
        let thumbURL = StoragePath.thumbnailFile(id: medicineId)

        try ocrImageData.write(to: imageURL, options: .atomic)
        try thumbnailData.write(to: thumbURL, options: .atomic)

        return (imageFilename, thumbFilename)
    }

    /// Load the full image for a medicine.
    func loadImage(for medicineId: String) -> UIImage? {
        let url = StoragePath.imageFile(id: medicineId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Load the thumbnail for a medicine.
    func loadThumbnail(for medicineId: String) -> UIImage? {
        let url = StoragePath.thumbnailFile(id: medicineId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Delete all images for a medicine.
    func deleteImages(for medicineId: String) throws {
        let imageURL = StoragePath.imageFile(id: medicineId)
        let thumbURL = StoragePath.thumbnailFile(id: medicineId)

        let fm = FileManager.default
        if fm.fileExists(atPath: imageURL.path) {
            try fm.removeItem(at: imageURL)
        }
        if fm.fileExists(atPath: thumbURL.path) {
            try fm.removeItem(at: thumbURL)
        }
    }

    /// Calculate total storage used by images (for UI display).
    func totalStorageUsed() -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default

        for dir in [StoragePath.imagesDirectory, StoragePath.thumbnailsDirectory] {
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
                }
            }
        }

        return total
    }

    /// Format bytes as human-readable string.
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
```

#### Complete Integration Example: Save Scanned Medicine

```swift
/// End-to-end flow: process image -> OCR -> parse -> save
func saveScanResult(imageData: Data) async throws -> Medicine {
    // Step 1: Process image (downscale + thumbnails)
    guard let processed = ImagePipeline.process(imageData: imageData) else {
        throw AppError.imageProcessingFailed
    }

    // Step 2: Run OCR on the downscaled image
    let ocrImage = UIImage(cgImage: processed.ocrImage)
    let ocrResults = try await performOCR(on: ocrImage)

    // Step 3: Parse medicine info
    let parsed = MedicineOCRParser.parse(ocrResults: ocrResults)

    // Step 4: Create Medicine model
    var medicine = Medicine(
        name: parsed.allText.components(separatedBy: "\n").first ?? "Unknown",
        dose: parsed.doses.first?.rawMatch ?? "",
        form: parsed.form?.form ?? "",
        quantity: Int(parsed.quantities.first?.count ?? "0") ?? 0,
        quantityUnit: parsed.quantities.first?.unit ?? "",
        expirationDate: parsed.expirationDate?.parsedDate,
        notes: ""
    )

    // Step 5: Save images
    let (imgFile, thumbFile) = try await ImageStore.shared.saveImages(
        ocrImageData: processed.ocrJPEGData,
        thumbnailData: processed.thumbnailJPEGData,
        for: medicine.id
    )
    medicine.imageFilename = imgFile
    medicine.thumbnailFilename = thumbFile

    // Step 6: Persist medicine to JSON
    try await PersistenceManager.shared.addMedicine(medicine)

    return medicine
}

enum AppError: Error, LocalizedError {
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image. Please try again with a clearer photo."
        }
    }
}
```

---

## Summary of Key Recommendations

| Area | Recommendation |
|---|---|
| **OCR Level** | `.accurate` with `usesLanguageCorrection = true` |
| **Languages** | `["es", "en"]` (Spanish first for LatAm market) |
| **Image Source** | `PhotosPicker` (primary, no permissions needed) + Camera (iPad only, needs capability) |
| **Image Size** | 1600px OCR, 512px thumbnail, JPEG 0.7-0.8 |
| **Image Resize** | `CGImageSource` downsampling (ImageIO) -- Apple recommended |
| **Parsing** | NSRegularExpression with bilingual pattern sets |
| **Notifications** | `UNCalendarNotificationTrigger`, 7-day rolling window |
| **Fallback** | In-app timer-based reminder banners when notifications denied |
| **Persistence** | Actor-based JSON + FileManager, images as separate JPEG files |
| **Thread Safety** | All I/O through actors; OCR on background via async/await |

---

## Sources

- [VNRecognizeTextRequest -- Apple Developer Documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [recognitionLanguages -- Apple Developer Documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/recognitionlanguages)
- [Recognizing Text with the Vision Framework -- Create with Swift](https://www.createwithswift.com/recognizing-text-with-the-vision-framework/)
- [Discover Swift Enhancements in the Vision Framework -- WWDC24](https://developer.apple.com/videos/play/wwdc2024/10163/)
- [Vision Framework in Swift for iOS Development 2025 Edition -- Bitcot](https://www.bitcot.com/vision-framework-in-swift-for-ios-development/)
- [Scheduling Notifications -- Hacking with Swift](https://www.hackingwithswift.com/read/21/2/scheduling-notifications-unusernotificationcenter-and-unnotificationrequest)
- [Scheduling Local Notifications -- Hacking with Swift SwiftUI](https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications)
- [Creating and Scheduling Notifications with async/await -- Create with Swift](https://www.createwithswift.com/notifications-tutorial-creating-and-scheduling-user-notifications-with-async-await/)
- [Local Notifications Guide -- Tanaschita](https://tanaschita.com/ios-local-notifications-guide/)
- [UNUserNotificationCenter -- Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Image Resizing Techniques -- NSHipster](https://nshipster.com/image-resizing/)
- [Reducing Memory Footprint When Using UIImage -- Swift Senpai](https://swiftsenpai.com/development/reduce-uiimage-memory-footprint/)
- [Writing Data to the Documents Directory -- Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/writing-data-to-the-documents-directory)
- [Swift File Manager: Reading, Writing, and Deleting Files -- SwiftyPlace](https://www.swiftyplace.com/blog/file-manager-in-swift-reading-writing-and-deleting-files-and-directories)
- [Requesting Access to Capabilities for App Playgrounds -- Apple Developer](https://developer.apple.com/documentation/swift-playgrounds/project-capabilities)
- [Swift Playgrounds Release Notes -- Apple Developer](https://developer.apple.com/swift-playground/release-notes/)
- [Swift Regex -- Apple Developer Documentation](https://developer.apple.com/documentation/swift/regex)
- [Mastering Swift Local Notifications -- Vikram Kumar (Medium)](https://vikramios.medium.com/mastering-swift-local-notifications-a-developers-guide-f56b77ab64cc)
