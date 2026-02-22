# MedShelf -- Technical Specification

**Version:** 1.0
**Date:** 2026-02-21
**Target:** Swift Student Challenge 2026
**Format:** App Playground (.swiftpm), single ZIP <= 25 MB

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Model](#2-data-model)
3. [Persistence Layer](#3-persistence-layer)
4. [OCR Pipeline](#4-ocr-pipeline)
5. [Alert Engine](#5-alert-engine)
6. [Schedule Engine](#6-schedule-engine)
7. [Notification Manager](#7-notification-manager)
8. [Image Pipeline](#8-image-pipeline)
9. [Demo Mode](#9-demo-mode)
10. [File Organization](#10-file-organization)
11. [Dependencies](#11-dependencies)
12. [Performance Budget](#12-performance-budget)

---

## 1. Architecture Overview

### 1.1 Project Format

MedShelf is a single-module `.swiftpm` App Playground. All Swift source files, resources, and assets live inside one executable target (`AppModule`) with path `"."` (project root). There are no external SPM dependencies. The project compiles and runs in both Swift Playgrounds 4.6+ and Xcode 26+.

### 1.2 Pattern: MVVM with Observable

The app follows **Model-View-ViewModel** using Swift's `@Observable` macro (iOS 17+) for ViewModels and plain `Codable` structs for Models. Service-layer objects (persistence, OCR, notifications, image processing) are implemented as **actors** or **singletons** injected via the SwiftUI environment.

```
┌─────────────────────────────────────────────────┐
│                    Views (SwiftUI)               │
│  MedicineListView, MedicineDetailView,           │
│  ScanView, ScheduleView, SettingsView            │
└──────────────────────┬──────────────────────────┘
                       │ binds via @Observable
┌──────────────────────▼──────────────────────────┐
│                  ViewModels                      │
│  InventoryViewModel, ScanViewModel,              │
│  ScheduleViewModel, SettingsViewModel            │
└──────────────────────┬──────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────┐
│                   Services                       │
│  JSONStore (actor), ImageStore (actor),           │
│  OCRManager, NotificationManager (actor),        │
│  AlertEngine, ScheduleEngine, DemoDataService    │
└──────────────────────┬──────────────────────────┘
                       │ reads/writes
┌──────────────────────▼──────────────────────────┐
│              Models (Codable structs)            │
│  Medicine, Schedule, DoseLog, AppSettings        │
└─────────────────────────────────────────────────┘
```

### 1.3 Data Flow

1. **Views** observe `@Observable` ViewModels.
2. **ViewModels** hold in-memory arrays of model structs and expose computed properties for the UI.
3. **ViewModels** call service actors for persistence, OCR, and notifications.
4. All file I/O flows through the `JSONStore` actor; all image I/O flows through the `ImageStore` actor.
5. `AlertEngine` and `ScheduleEngine` are pure-function utilities (no state); ViewModels call them and store results.

---

## 2. Data Model

All models are value types (`struct`) conforming to `Identifiable`, `Codable`, and `Hashable`. Enums use `String` raw values for JSON stability.

### 2.1 Enumerations

```swift
import Foundation

// MARK: - MedicineForm

/// Pharmaceutical form of a medicine.
enum MedicineForm: String, Codable, CaseIterable, Hashable {
    case tablet
    case capsule
    case syrup
    case cream
    case drops
    case injection
    case other

    var displayName: String {
        switch self {
        case .tablet:    return "Tablet"
        case .capsule:   return "Capsule"
        case .syrup:     return "Syrup"
        case .cream:     return "Cream"
        case .drops:     return "Drops"
        case .injection: return "Injection"
        case .other:     return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .tablet:    return "pill.fill"
        case .capsule:   return "capsule.fill"
        case .syrup:     return "flask.fill"
        case .cream:     return "bandage.fill"
        case .drops:     return "drop.fill"
        case .injection: return "syringe.fill"
        case .other:     return "cross.vial.fill"
        }
    }
}

// MARK: - QuantityUnit

/// Unit of measurement for remaining quantity.
enum QuantityUnit: String, Codable, CaseIterable, Hashable {
    case pills
    case ml
    case g
    case units

    var displayName: String {
        switch self {
        case .pills: return "pills"
        case .ml:    return "mL"
        case .g:     return "g"
        case .units: return "units"
        }
    }

    var abbreviation: String {
        displayName
    }
}

// MARK: - ScheduleFrequency

/// How often a medicine is taken.
enum ScheduleFrequency: Codable, Hashable {
    case everyXHours(Int)
    case timesOfDay([String])   // Each string is "HH:mm" in 24-hour format

    /// Human-readable description of the frequency.
    var displayText: String {
        switch self {
        case .everyXHours(let hours):
            return "Every \(hours) hour\(hours == 1 ? "" : "s")"
        case .timesOfDay(let times):
            let formatted = times.sorted().joined(separator: ", ")
            return "\(times.count)x daily (\(formatted))"
        }
    }

    /// Number of doses per day for stock estimation.
    var dosesPerDay: Double {
        switch self {
        case .everyXHours(let hours):
            return 24.0 / Double(max(hours, 1))
        case .timesOfDay(let times):
            return Double(times.count)
        }
    }
}

// MARK: - DoseStatus

/// Whether a scheduled dose was taken or skipped.
enum DoseStatus: String, Codable, Hashable {
    case taken
    case skipped
}

// MARK: - ExpiryStatus

/// Computed expiration status for display. Not persisted.
enum ExpiryStatus: Hashable {
    case expired
    case expiringSoon(daysLeft: Int)
    case ok
    case unknown   // No expiration date set

    var displayText: String {
        switch self {
        case .expired:
            return "Expired"
        case .expiringSoon(let days):
            return "Expires in \(days) day\(days == 1 ? "" : "s")"
        case .ok:
            return "OK"
        case .unknown:
            return "No expiry date"
        }
    }

    var color: String {
        switch self {
        case .expired:        return "red"
        case .expiringSoon:   return "orange"
        case .ok:             return "green"
        case .unknown:        return "gray"
        }
    }
}

// MARK: - StockStatus

/// Computed stock level status for display. Not persisted.
enum StockStatus: Hashable {
    case outOfStock
    case low(daysRemaining: Int)
    case adequate
    case unknown    // No schedule to estimate against

    var displayText: String {
        switch self {
        case .outOfStock:
            return "Out of stock"
        case .low(let days):
            return "\(days) day\(days == 1 ? "" : "s") of supply left"
        case .adequate:
            return "Well stocked"
        case .unknown:
            return "No schedule"
        }
    }
}
```

### 2.2 Medicine

```swift
import Foundation

/// A medicine item in the user's inventory.
struct Medicine: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var doseText: String                // e.g., "500 mg", "10 mg/5 mL"
    var form: MedicineForm
    var quantityRemaining: Double       // Current remaining quantity
    var quantityUnit: QuantityUnit
    var expirationDate: Date?
    var photoFilename: String?          // Filename of display image in Images/
    var thumbnailFilename: String?      // Filename of thumbnail in Thumbnails/
    var ocrRawText: String?             // Full OCR text for reference
    var ocrConfidence: Double?          // 0.0 - 1.0 parse confidence
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        doseText: String = "",
        form: MedicineForm = .other,
        quantityRemaining: Double = 0,
        quantityUnit: QuantityUnit = .pills,
        expirationDate: Date? = nil,
        photoFilename: String? = nil,
        thumbnailFilename: String? = nil,
        ocrRawText: String? = nil,
        ocrConfidence: Double? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.doseText = doseText
        self.form = form
        self.quantityRemaining = quantityRemaining
        self.quantityUnit = quantityUnit
        self.expirationDate = expirationDate
        self.photoFilename = photoFilename
        self.thumbnailFilename = thumbnailFilename
        self.ocrRawText = ocrRawText
        self.ocrConfidence = ocrConfidence
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

### 2.3 Schedule

```swift
import Foundation

/// A dosing schedule attached to a medicine.
struct Schedule: Identifiable, Codable, Hashable {
    let id: UUID
    let medicineId: UUID
    var dosePerIntake: Double           // Amount consumed per dose (e.g., 1.0 pill, 5.0 mL)
    var frequency: ScheduleFrequency
    var startDate: Date
    var endDate: Date?                  // nil = indefinite
    var notificationsEnabled: Bool

    init(
        id: UUID = UUID(),
        medicineId: UUID,
        dosePerIntake: Double = 1.0,
        frequency: ScheduleFrequency = .timesOfDay(["08:00"]),
        startDate: Date = Date(),
        endDate: Date? = nil,
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.medicineId = medicineId
        self.dosePerIntake = dosePerIntake
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.notificationsEnabled = notificationsEnabled
    }
}
```

### 2.4 DoseLog

```swift
import Foundation

/// A record of a single dose event (taken or skipped).
struct DoseLog: Identifiable, Codable, Hashable {
    let id: UUID
    let scheduleId: UUID
    let medicineId: UUID
    let scheduledTime: Date             // When the dose was supposed to happen
    var status: DoseStatus
    var actionTime: Date?               // When the user actually tapped Taken/Skip

    init(
        id: UUID = UUID(),
        scheduleId: UUID,
        medicineId: UUID,
        scheduledTime: Date,
        status: DoseStatus,
        actionTime: Date? = nil
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.medicineId = medicineId
        self.scheduledTime = scheduledTime
        self.status = status
        self.actionTime = actionTime
    }
}
```

### 2.5 AppSettings

```swift
import Foundation

/// Global application settings. Persisted as a single JSON object.
struct AppSettings: Codable, Hashable {
    var expiryWarningDays: Int          // Days before expiry to show warning
    var lowStockDays: Int               // Days of supply remaining to trigger low-stock alert
    var isDemoMode: Bool                // Whether demo data is currently loaded

    init(
        expiryWarningDays: Int = 30,
        lowStockDays: Int = 7,
        isDemoMode: Bool = false
    ) {
        self.expiryWarningDays = expiryWarningDays
        self.lowStockDays = lowStockDays
        self.isDemoMode = isDemoMode
    }

    static let `default` = AppSettings()
}
```

---

## 3. Persistence Layer

### 3.1 JSONStore Actor

All JSON file I/O is serialized through a single actor to prevent data races. No external database framework is needed; Foundation's `JSONEncoder`/`JSONDecoder` plus `FileManager` are sufficient for the expected data volume (tens of medicines, not thousands).

```swift
import Foundation

actor JSONStore {
    static let shared = JSONStore()

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    // MARK: - File Paths

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func jsonFileURL(for filename: String) -> URL {
        documentsURL.appendingPathComponent("\(filename).json")
    }

    // MARK: - CRUD Operations

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: jsonFileURL(for: filename), options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let data = try Data(contentsOf: jsonFileURL(for: filename))
        return try decoder.decode(type, from: data)
    }

    func loadOrDefault<T: Decodable>(_ type: T.Type, from filename: String, default fallback: T) -> T {
        (try? load(type, from: filename)) ?? fallback
    }

    func delete(filename: String) throws {
        let url = jsonFileURL(for: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func exists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: jsonFileURL(for: filename).path)
    }
}
```

### 3.2 File Names and Directory Structure

All user data lives in the app's Documents directory. The structure at runtime:

```
<AppSandbox>/Documents/
├── medicines.json          // [Medicine] array
├── schedules.json          // [Schedule] array
├── dose_logs.json          // [DoseLog] array
├── settings.json           // AppSettings object
├── Images/                 // Display-resolution photos (512px, JPEG 0.7)
│   ├── <uuid>.jpg
│   └── ...
└── Thumbnails/             // List-view thumbnails (256px, JPEG 0.6)
    ├── <uuid>_thumb.jpg
    └── ...
```

**JSON file constants:**

```swift
enum StoreFile {
    static let medicines  = "medicines"
    static let schedules  = "schedules"
    static let doseLogs   = "dose_logs"
    static let settings   = "settings"
}
```

### 3.3 ImageStore Actor

```swift
import UIKit

actor ImageStore {
    static let shared = ImageStore()

    private let fileManager = FileManager.default

    private var imagesDir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var thumbnailsDir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Save display image and thumbnail. Returns (photoFilename, thumbnailFilename).
    func save(
        displayImageData: Data,
        thumbnailData: Data,
        id: UUID
    ) throws -> (photo: String, thumbnail: String) {
        let photoName = "\(id.uuidString).jpg"
        let thumbName = "\(id.uuidString)_thumb.jpg"

        try displayImageData.write(to: imagesDir.appendingPathComponent(photoName), options: .atomic)
        try thumbnailData.write(to: thumbnailsDir.appendingPathComponent(thumbName), options: .atomic)

        return (photoName, thumbName)
    }

    func loadImage(filename: String) -> UIImage? {
        let url = imagesDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(filename: String) -> UIImage? {
        let url = thumbnailsDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteImages(id: UUID) throws {
        let photoURL = imagesDir.appendingPathComponent("\(id.uuidString).jpg")
        let thumbURL = thumbnailsDir.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        if fileManager.fileExists(atPath: photoURL.path) {
            try fileManager.removeItem(at: photoURL)
        }
        if fileManager.fileExists(atPath: thumbURL.path) {
            try fileManager.removeItem(at: thumbURL)
        }
    }

    func totalStorageBytes() -> Int64 {
        var total: Int64 = 0
        for dir in [imagesDir, thumbnailsDir] {
            if let files = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey]
            ) {
                for file in files {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
                }
            }
        }
        return total
    }
}
```

### 3.4 Data Migration Considerations

Because the app uses plain JSON files, forward-compatible migration is straightforward:

1. **Adding new fields:** Make them optional (`?`) in the struct. `JSONDecoder` silently ignores missing keys when the property has a default or is optional.
2. **Renaming fields:** Use `CodingKeys` to map old JSON keys to new property names.
3. **Removing fields:** Old JSON data with extra keys is silently ignored by `JSONDecoder`.
4. **Schema version:** If structural changes are needed, add a `schemaVersion: Int` to `AppSettings`. On load, check the version and run migration functions before decoding other files.

For the SSC submission, no migration is needed -- first-run data will always be fresh or demo-seeded.

---

## 4. OCR Pipeline

### 4.1 End-to-End Flow

```
┌─────────────┐    ┌────────────────┐    ┌─────────────────────┐
│ 1. Acquire   │───>│ 2. Preprocess  │───>│ 3. VNRecognize      │
│   Image      │    │   (downscale   │    │   TextRequest        │
│ (PhotosPicker│    │    to 1600px)  │    │   (.accurate,        │
│  or Camera)  │    │                │    │    es + en)           │
└─────────────┘    └────────────────┘    └──────────┬────────────┘
                                                    │
┌─────────────┐    ┌────────────────┐    ┌──────────▼────────────┐
│ 6. Save      │<──│ 5. Review UI   │<──│ 4. Parse              │
│   Medicine   │    │   (user edits  │    │   (regex extraction   │
│   + Images   │    │    & confirms) │    │    of dose, form,     │
└─────────────┘    └────────────────┘    │    expiry, quantity)   │
                                          └─────────────────────┘
```

### 4.2 OCRManager

```swift
import Vision
import UIKit

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

struct OCRLine {
    let text: String
    let confidence: Float   // 0.0 - 1.0
}

struct OCRManager {

    /// Run VNRecognizeTextRequest on a CGImage. Returns recognized lines with confidence.
    /// Must be called from a background context (it performs synchronous Vision work internally
    /// but is wrapped in withCheckedThrowingContinuation for async callers).
    static func recognizeText(in cgImage: CGImage) async throws -> [OCRLine] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let lines: [OCRLine] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return OCRLine(text: candidate.string, confidence: candidate.confidence)
                }

                continuation.resume(returning: lines)
            }

            // Configuration for bilingual medicine packaging
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
}
```

### 4.3 Text Parsing -- Regex Patterns

All parsing functions accept the full OCR text (lines joined by `\n`) and return optional extracted values.

#### 4.3.1 Dose Extraction

```swift
import Foundation

struct ParsedDose {
    let value: String       // "500", "0.25"
    let unit: String        // "mg", "mcg", "mL"
    let rawMatch: String    // "500 mg"
}

enum OCRParser {

    /// Extract dose values: "500 mg", "10 mcg/mL", "100 mg/5 mL"
    static func extractDoses(from text: String) -> [ParsedDose] {
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(mg|mcg|µg|g|kg|m[lL]|[lL]|IU|UI|mEq)(?:\s*/\s*\d*\s*m?[lL])?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let fullRange = Range(match.range, in: text) else { return nil }
            return ParsedDose(
                value: String(text[valueRange]),
                unit: String(text[unitRange]).lowercased(),
                rawMatch: String(text[fullRange])
            )
        }
    }
```

#### 4.3.2 Form Detection (Bilingual)

```swift
    /// Detect pharmaceutical form from bilingual text. Returns the first match.
    static func extractForm(from text: String) -> MedicineForm? {
        let mappings: [(pattern: String, form: MedicineForm)] = [
            // English
            (#"\b(?:tablets?|tabs?)\b"#,         .tablet),
            (#"\b(?:capsules?|caps?)\b"#,        .capsule),
            (#"\b(?:syrups?)\b"#,                .syrup),
            (#"\b(?:creams?|ointments?)\b"#,     .cream),
            (#"\b(?:drops?|gtt)\b"#,             .drops),
            (#"\b(?:injection|injectable|inj)\b"#, .injection),
            // Spanish
            (#"\b(?:comprimidos?|tabletas?|pastillas?|grageas?)\b"#, .tablet),
            (#"\b(?:c[aá]psulas?)\b"#,           .capsule),
            (#"\b(?:jarabes?|sirope)\b"#,        .syrup),
            (#"\b(?:cremas?|pomadas?|ung[uü]entos?|gel)\b"#, .cream),
            (#"\b(?:gotas)\b"#,                  .drops),
            (#"\b(?:inyecci[oó]n|inyectable)\b"#, .injection),
        ]

        let lowered = text.lowercased()
        for (pattern, form) in mappings {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil {
                return form
            }
        }
        return nil
    }
```

#### 4.3.3 Expiration Date Extraction (Bilingual)

```swift
    struct ParsedExpiration {
        let label: String       // "EXP", "CAD", "VENCE", etc.
        let dateString: String  // "03/2027"
        let date: Date?
    }

    /// Extract expiration date. Looks for label + date pattern.
    static func extractExpiration(from text: String) -> ParsedExpiration? {
        let labelPattern = #"(?:EXP(?:IRY|IRES)?\.?\s*(?:DATE)?|USE\s*BY|BEST\s*BEFORE|CAD(?:UCIDAD)?|FECHA\s*(?:DE\s*)?(?:CADUCIDAD|VENCIMIENTO|EXPIRACI[OÓ]N)|VENCE|VTO\.?|VENCIMIENTO|FV|VAL(?:IDEZ)?)"#
        let datePattern = #"(\d{1,2})\s*[/.\-]\s*(\d{4})|(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{2,4})|(\d{4})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{1,2})|([A-Za-z]{3,})\s*[/.\-\s]\s*(\d{4})"#
        let combinedPattern = "(\(labelPattern))[:\\s./\\-]*(\(datePattern))"

        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: .caseInsensitive) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let fullRange = Range(match.range, in: text) else {
            return nil
        }

        let raw = String(text[fullRange])
        var label = ""
        if let labelRange = Range(match.range(at: 1), in: text) {
            label = String(text[labelRange]).trimmingCharacters(in: .whitespaces)
        }
        let dateString = raw
            .replacingOccurrences(of: label, with: "")
            .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: ":.-")))

        let parsedDate = parseDate(dateString)
        return ParsedExpiration(label: label, dateString: dateString, date: parsedDate)
    }

    /// Parse date strings in common pharmaceutical formats.
    /// For month-only formats (MM/YYYY), returns the last day of that month.
    private static func parseDate(_ string: String) -> Date? {
        let cleaned = string.trimmingCharacters(in: .whitespaces)
        let formats: [(dateFormat: String, regex: String)] = [
            ("dd/MM/yyyy", #"^\d{1,2}/\d{1,2}/\d{4}$"#),
            ("MM/yyyy",    #"^\d{1,2}/\d{4}$"#),
            ("yyyy-MM-dd", #"^\d{4}-\d{1,2}-\d{1,2}$"#),
            ("dd.MM.yyyy", #"^\d{1,2}\.\d{1,2}\.\d{4}$"#),
            ("MM.yyyy",    #"^\d{1,2}\.\d{4}$"#),
            ("MM-yyyy",    #"^\d{1,2}-\d{4}$"#),
            ("dd-MM-yyyy", #"^\d{1,2}-\d{1,2}-\d{4}$"#),
        ]

        for (fmt, pattern) in formats {
            if cleaned.range(of: pattern, options: .regularExpression) != nil {
                let formatter = DateFormatter()
                formatter.dateFormat = fmt
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = formatter.date(from: cleaned) {
                    if !fmt.contains("dd") {
                        // Month-only: return last day of that month
                        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: date)
                    }
                    return date
                }
            }
        }

        // Try month-name formats: "MAR 2027", "Marzo 2027"
        let monthNamePattern = #"^([A-Za-zÁÉÍÓÚáéíóú]+)\s*[/\-.\s]\s*(\d{4})$"#
        if let regex = try? NSRegularExpression(pattern: monthNamePattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let monthRange = Range(match.range(at: 1), in: cleaned),
           let yearRange = Range(match.range(at: 2), in: cleaned) {
            let monthStr = String(cleaned[monthRange])
            let yearStr = String(cleaned[yearRange])
            for localeId in ["en_US_POSIX", "es_ES"] {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: localeId)
                for fmt in ["MMM yyyy", "MMMM yyyy"] {
                    formatter.dateFormat = fmt
                    if let date = formatter.date(from: "\(monthStr) \(yearStr)") {
                        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: date)
                    }
                }
            }
        }

        return nil
    }
```

#### 4.3.4 Quantity Extraction

```swift
    struct ParsedQuantity {
        let count: Int
        let unit: String
        let rawMatch: String
    }

    /// Extract package quantity: "30 tablets", "120 capsulas", "100 mL"
    static func extractQuantity(from text: String) -> ParsedQuantity? {
        let pattern = #"(\d+)\s*(tablets?|tabs?|capsules?|caps?|pills?|mL|ml|L|l|g|mg|comprimidos?|tabletas?|c[aá]psulas?|pastillas?|grageas?|sobres?|ampollas?|unidades?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let countRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let fullRange = Range(match.range, in: text),
              let count = Int(text[countRange]) else {
            return nil
        }
        return ParsedQuantity(
            count: count,
            unit: String(text[unitRange]),
            rawMatch: String(text[fullRange])
        )
    }
}
```

### 4.4 Confidence Scoring

```swift
extension OCRParser {

    /// Compute an overall confidence score (0.0 - 1.0) based on OCR quality and
    /// how many fields were successfully parsed.
    static func computeConfidence(
        averageOCRConfidence: Float,
        hasDose: Bool,
        hasForm: Bool,
        hasExpiration: Bool,
        hasQuantity: Bool
    ) -> Double {
        var score = Double(averageOCRConfidence) * 0.40  // 40% from Vision confidence
        if hasDose       { score += 0.15 }
        if hasForm       { score += 0.15 }
        if hasExpiration  { score += 0.20 }
        if hasQuantity   { score += 0.10 }
        return min(score, 1.0)
    }
}
```

**UI thresholds:**

| Confidence | Indicator | Behavior |
|---|---|---|
| >= 0.8 | Green check | Auto-fill all fields; user can confirm with one tap |
| 0.5 -- 0.79 | Yellow warning | Auto-fill with highlight; user should review |
| < 0.5 | Orange alert | Partial fill; prompt user for manual entry |

### 4.5 Full Parse Pipeline (called from ScanViewModel)

```swift
struct OCRResult {
    let rawText: String
    let suggestedName: String?
    let suggestedDose: String?
    let suggestedForm: MedicineForm?
    let suggestedExpiry: Date?
    let suggestedQuantity: Int?
    let suggestedQuantityUnit: QuantityUnit?
    let confidence: Double
}

extension OCRManager {

    /// Full pipeline: image -> OCR -> parse -> structured result.
    static func scan(image: CGImage) async throws -> OCRResult {
        let lines = try await recognizeText(in: image)
        let fullText = lines.map(\.text).joined(separator: "\n")
        let avgConf = lines.isEmpty ? 0 : lines.map(\.confidence).reduce(0, +) / Float(lines.count)

        let doses = OCRParser.extractDoses(from: fullText)
        let form = OCRParser.extractForm(from: fullText)
        let expiry = OCRParser.extractExpiration(from: fullText)
        let quantity = OCRParser.extractQuantity(from: fullText)

        let confidence = OCRParser.computeConfidence(
            averageOCRConfidence: avgConf,
            hasDose: !doses.isEmpty,
            hasForm: form != nil,
            hasExpiration: expiry != nil,
            hasQuantity: quantity != nil
        )

        // Heuristic: first line of OCR text is often the product name
        let suggestedName = lines.first?.text

        // Map Spanish units to QuantityUnit
        let suggestedUnit: QuantityUnit? = {
            guard let q = quantity else { return nil }
            let lower = q.unit.lowercased()
            if lower.contains("ml") || lower.contains("l") { return .ml }
            if lower.contains("g") && !lower.contains("gragea") { return .g }
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
```

---

## 5. Alert Engine

The `AlertEngine` is a stateless utility. ViewModels call its pure functions whenever the medicine list or settings change, then store the results for display.

### 5.1 Expiry Status

```swift
import Foundation

enum AlertEngine {

    /// Determine expiry status for a medicine.
    /// - Parameters:
    ///   - expirationDate: The medicine's expiration date (nil = unknown).
    ///   - warningDays: Number of days before expiry to flag as "expiring soon".
    ///   - referenceDate: The date to compare against (defaults to now).
    static func expiryStatus(
        expirationDate: Date?,
        warningDays: Int = 30,
        referenceDate: Date = Date()
    ) -> ExpiryStatus {
        guard let expDate = expirationDate else {
            return .unknown
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfExpiry = calendar.startOfDay(for: expDate)

        guard let daysUntil = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry).day else {
            return .unknown
        }

        if daysUntil < 0 {
            return .expired
        } else if daysUntil <= warningDays {
            return .expiringSoon(daysLeft: daysUntil)
        } else {
            return .ok
        }
    }
```

### 5.2 Low Stock Computation

```swift
    /// Estimate daily consumption from a schedule.
    /// Formula: dosePerIntake * dosesPerDay
    static func dailyConsumption(schedule: Schedule) -> Double {
        schedule.dosePerIntake * schedule.frequency.dosesPerDay
    }

    /// Determine stock status for a medicine.
    /// - Parameters:
    ///   - quantityRemaining: Current stock level.
    ///   - schedule: Active schedule (nil = no schedule, status is .unknown).
    ///   - lowStockDays: Threshold for "low" alert.
    static func stockStatus(
        quantityRemaining: Double,
        schedule: Schedule?,
        lowStockDays: Int = 7
    ) -> StockStatus {
        if quantityRemaining <= 0 {
            return .outOfStock
        }

        guard let schedule = schedule else {
            return .unknown
        }

        let daily = dailyConsumption(schedule: schedule)
        guard daily > 0 else {
            return .adequate
        }

        let daysRemaining = Int(quantityRemaining / daily)

        if daysRemaining <= 0 {
            return .outOfStock
        } else if daysRemaining <= lowStockDays {
            return .low(daysRemaining: daysRemaining)
        } else {
            return .adequate
        }
    }
}
```

### 5.3 When to Recompute

Alerts are recomputed:
1. **On app launch** -- InventoryViewModel loads all medicines and runs both checks.
2. **On foreground resume** -- via `scenePhase` `.active` observer (dates may have changed).
3. **After any medicine edit** -- quantity, expiry, or schedule changes.
4. **After recording a dose** -- quantity decrements, stock status may change.

Alerts are **not** background-computed. They are lightweight pure functions (microseconds) that run on the main actor as part of ViewModel updates.

---

## 6. Schedule Engine

The `ScheduleEngine` generates concrete dose instances from abstract schedules for a rolling time window.

### 6.1 DoseInstance (Transient, Not Persisted)

```swift
import Foundation

/// A single expected dose at a specific time. Generated from a Schedule, not stored.
struct DoseInstance: Identifiable, Hashable {
    let id: String              // Deterministic: "\(scheduleId)-\(isoTimestamp)"
    let scheduleId: UUID
    let medicineId: UUID
    let scheduledTime: Date
    var log: DoseLog?           // Non-nil if a log entry exists for this instance

    var isPast: Bool {
        scheduledTime < Date()
    }

    var isTaken: Bool {
        log?.status == .taken
    }

    var isSkipped: Bool {
        log?.status == .skipped
    }

    var isPending: Bool {
        log == nil
    }
}
```

### 6.2 Dose Generation

```swift
enum ScheduleEngine {

    /// Generate all dose instances for a schedule within a date range.
    /// This is the core function for "Today's Doses" and the weekly calendar.
    static func generateInstances(
        schedule: Schedule,
        from startDate: Date,
        to endDate: Date,
        existingLogs: [DoseLog]
    ) -> [DoseInstance] {
        let calendar = Calendar.current
        var instances: [DoseInstance] = []

        // Clamp to schedule bounds
        let effectiveStart = max(startDate, schedule.startDate)
        let effectiveEnd: Date
        if let schedEnd = schedule.endDate {
            effectiveEnd = min(endDate, schedEnd)
        } else {
            effectiveEnd = endDate
        }

        guard effectiveStart <= effectiveEnd else { return [] }

        switch schedule.frequency {
        case .timesOfDay(let times):
            // Iterate day by day
            var currentDay = calendar.startOfDay(for: effectiveStart)
            while currentDay <= effectiveEnd {
                for timeString in times {
                    if let time = parseTimeString(timeString),
                       let doseTime = calendar.date(
                        bySettingHour: time.hour, minute: time.minute, second: 0, of: currentDay
                       ),
                       doseTime >= effectiveStart && doseTime <= effectiveEnd {

                        let instanceId = "\(schedule.id.uuidString)-\(iso(doseTime))"
                        let matchingLog = existingLogs.first {
                            $0.scheduleId == schedule.id &&
                            calendar.isDate($0.scheduledTime, equalTo: doseTime, toGranularity: .minute)
                        }

                        instances.append(DoseInstance(
                            id: instanceId,
                            scheduleId: schedule.id,
                            medicineId: schedule.medicineId,
                            scheduledTime: doseTime,
                            log: matchingLog
                        ))
                    }
                }
                currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
            }

        case .everyXHours(let interval):
            // Start from the schedule's start time and step forward
            var cursor = schedule.startDate
            while cursor <= effectiveEnd {
                if cursor >= effectiveStart {
                    let instanceId = "\(schedule.id.uuidString)-\(iso(cursor))"
                    let matchingLog = existingLogs.first {
                        $0.scheduleId == schedule.id &&
                        calendar.isDate($0.scheduledTime, equalTo: cursor, toGranularity: .minute)
                    }
                    instances.append(DoseInstance(
                        id: instanceId,
                        scheduleId: schedule.id,
                        medicineId: schedule.medicineId,
                        scheduledTime: cursor,
                        log: matchingLog
                    ))
                }
                cursor = calendar.date(byAdding: .hour, value: interval, to: cursor)!
            }
        }

        return instances.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// Generate today's dose instances for all active schedules.
    static func todaysDoses(
        schedules: [Schedule],
        logs: [DoseLog]
    ) -> [DoseInstance] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return schedules.flatMap { schedule in
            generateInstances(schedule: schedule, from: startOfDay, to: endOfDay, existingLogs: logs)
        }
        .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// Generate a 7-day rolling window of dose instances for notification scheduling.
    static func upcomingDoses(
        schedules: [Schedule],
        logs: [DoseLog],
        days: Int = 7
    ) -> [DoseInstance] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: now)!
        return schedules.flatMap { schedule in
            generateInstances(schedule: schedule, from: now, to: end, existingLogs: logs)
        }
        .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    // MARK: - Helpers

    private static func parseTimeString(_ string: String) -> (hour: Int, minute: Int)? {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else {
            return nil
        }
        return (h, m)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func iso(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}
```

### 6.3 Recording a Dose (Taken / Skipped)

When the user taps "Taken" or "Skip" on a dose instance:

```swift
extension ScheduleEngine {

    /// Record a dose action. Returns the new DoseLog and the updated quantity.
    /// Caller is responsible for persisting both the log and the updated Medicine.
    static func recordDose(
        instance: DoseInstance,
        status: DoseStatus,
        schedule: Schedule,
        currentQuantity: Double
    ) -> (log: DoseLog, newQuantity: Double) {
        let log = DoseLog(
            scheduleId: instance.scheduleId,
            medicineId: instance.medicineId,
            scheduledTime: instance.scheduledTime,
            status: status,
            actionTime: Date()
        )

        var newQuantity = currentQuantity
        if status == .taken {
            newQuantity = max(0, currentQuantity - schedule.dosePerIntake)
        }
        // .skipped does not decrement quantity

        return (log, newQuantity)
    }
}
```

---

## 7. Notification Manager

### 7.1 Actor Definition

```swift
import UserNotifications

actor NotificationManager {
    static let shared = NotificationManager()

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func isAuthorized() async -> Bool {
        await authorizationStatus() == .authorized
    }
```

### 7.2 Permission Handling Flow

```
App Launch
    │
    ├─ Check authorizationStatus()
    │   ├─ .authorized  --> Schedule notifications normally
    │   ├─ .denied      --> Use in-app banners only; show subtle Settings hint
    │   ├─ .notDetermined --> Do NOT ask yet (wait for user action)
    │   └─ .provisional --> Schedule normally (quiet delivery)
    │
User creates first schedule with notifications enabled
    │
    ├─ If .notDetermined:
    │   ├─ Show pre-permission explanation screen
    │   ├─ User taps "Enable Reminders" --> requestPermission()
    │   │   ├─ Granted  --> Schedule notifications
    │   │   └─ Denied   --> Fall back to in-app banners
    │   └─ User taps "Not now" --> Fall back to in-app banners
    │
    └─ If .denied:
        └─ Show non-blocking hint: "Enable in Settings for reminders"
```

### 7.3 Scheduling Strategy

```swift
    // MARK: - Scheduling

    /// Schedule notifications for a rolling window of dose instances.
    /// Clears all existing pending notifications and reschedules from scratch.
    ///
    /// iOS imposes a limit of 64 pending local notifications per app.
    /// With a 7-day window:
    ///   - 5 medicines x 2 doses/day x 7 days = 70 (over limit)
    ///   - 5 medicines x 2 doses/day x 4 days = 40 (safe)
    ///
    /// Strategy: Fill up to 60 notifications (leaving 4 as buffer), prioritizing
    /// the nearest doses first.
    func scheduleNotifications(
        for instances: [DoseInstance],
        medicines: [UUID: String]       // medicineId -> name lookup
    ) async {
        let center = UNUserNotificationCenter.current()

        // Clear all pending
        center.removeAllPendingNotificationRequests()

        // Filter to future pending instances only, take up to 60
        let now = Date()
        let toSchedule = instances
            .filter { $0.scheduledTime > now && $0.isPending }
            .prefix(60)

        for instance in toSchedule {
            let content = UNMutableNotificationContent()
            content.title = "Medication Reminder"
            content.body = "Time to take \(medicines[instance.medicineId] ?? "your medicine")"
            content.sound = .default
            content.categoryIdentifier = "DOSE_REMINDER"
            content.userInfo = [
                "medicineId": instance.medicineId.uuidString,
                "scheduleId": instance.scheduleId.uuidString
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: instance.scheduledTime
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: instance.id,
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    /// Cancel all notifications for a specific medicine.
    func cancelNotifications(for medicineId: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let idsToRemove = pending.filter {
            $0.content.userInfo["medicineId"] as? String == medicineId.uuidString
        }.map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
    }

    /// Remove all pending notifications.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
```

### 7.4 Rescheduling Triggers

Notifications are rescheduled (full clear + rebuild) when:

| Trigger | Location |
|---|---|
| App enters foreground | `MedShelfApp.onChange(of: scenePhase)` |
| Schedule created/edited/deleted | `ScheduleViewModel.save()` / `delete()` |
| Dose recorded (Taken/Skip) | `ScheduleViewModel.recordDose()` |
| Medicine deleted | `InventoryViewModel.delete()` |

### 7.5 Graceful Degradation

When notifications are denied or unavailable:

1. All schedule features still work; only the push notification is omitted.
2. The "Today's Doses" view serves as an in-app reminder.
3. A subtle banner in Settings says: "Notifications are off. Enable in Settings for reminders."
4. The app never blocks functionality or nags repeatedly about permissions.

---

## 8. Image Pipeline

### 8.1 Image Acquisition

Two sources, both available in Swift Playgrounds:

| Source | Framework | Permissions | Availability |
|---|---|---|---|
| **PhotosPicker** | PhotosUI | None (out-of-process picker) | iOS 16+ / iPadOS 16+ |
| **Camera** | UIKit (`UIImagePickerController`) | `NSCameraUsageDescription` capability | iPad only |

The app checks `UIImagePickerController.isSourceTypeAvailable(.camera)` and hides the camera button when unavailable (Mac, Simulator).

### 8.2 Downscaling with ImageIO

Apple-recommended approach using `CGImageSource` for memory-efficient resizing. The original image is never fully decoded into a bitmap at its native resolution.

```swift
import ImageIO
import UIKit

enum ImagePipeline {

    /// Memory-efficient downsampling using ImageIO (no full-decode of original).
    static func downsample(data: Data, maxPixelSize: CGFloat) -> CGImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
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
```

### 8.3 Three-Tier Processing

```swift
    struct ProcessedImages {
        let ocrImage: CGImage           // 1600px long side -- fed to Vision
        let displayImage: CGImage       // 512px long side -- shown in detail view
        let thumbnail: CGImage          // 256px long side -- shown in list rows
        let displayJPEG: Data           // JPEG 0.7 of displayImage
        let thumbnailJPEG: Data         // JPEG 0.6 of thumbnail
    }

    /// Process raw photo data into three resolution tiers.
    static func process(imageData: Data) -> ProcessedImages? {
        guard let ocrImg = downsample(data: imageData, maxPixelSize: 1600),
              let displayImg = downsample(data: imageData, maxPixelSize: 512),
              let thumbImg = downsample(data: imageData, maxPixelSize: 256) else {
            return nil
        }

        guard let displayData = UIImage(cgImage: displayImg).jpegData(compressionQuality: 0.7),
              let thumbData = UIImage(cgImage: thumbImg).jpegData(compressionQuality: 0.6) else {
            return nil
        }

        return ProcessedImages(
            ocrImage: ocrImg,
            displayImage: displayImg,
            thumbnail: thumbImg,
            displayJPEG: displayData,
            thumbnailJPEG: thumbData
        )
    }
}
```

### 8.4 Size Targets

| Tier | Max Dimension | JPEG Quality | Target File Size | Purpose |
|---|---|---|---|---|
| OCR | 1600px | N/A (in-memory only) | Not stored | Fed to VNRecognizeTextRequest |
| Display | 512px | 0.7 | <= 200 KB | Detail view, scan review |
| Thumbnail | 256px | 0.6 | <= 50 KB | List rows, grid cells |

The OCR image is processed in-memory and never written to disk. Only the display and thumbnail versions are persisted.

### 8.5 Storage Size Management

With typical JPEG sizes:
- 30 medicines x (200 KB display + 50 KB thumbnail) = ~7.5 MB total image storage.
- This is well within the iOS sandbox capacity and does not affect ZIP size (user images are runtime-only, not bundled).

---

## 9. Demo Mode

### 9.1 Purpose

Judges have a maximum of 3 minutes. Demo mode pre-populates the app with realistic sample data so every feature is immediately visible without manual data entry.

### 9.2 Sample Data Set

The demo loads 5 medicines representing varied states:

```swift
import Foundation

enum DemoDataService {

    /// Generate demo medicines with varied states for SSC judging.
    static func makeDemoMedicines() -> [Medicine] {
        let now = Date()
        let calendar = Calendar.current

        return [
            // 1. Healthy stock, not expiring soon
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Amoxicillin",
                doseText: "500 mg",
                form: .capsule,
                quantityRemaining: 21,
                quantityUnit: .pills,
                expirationDate: calendar.date(byAdding: .month, value: 8, to: now),
                notes: "Antibiotic - take with food"
            ),

            // 2. Low stock
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Ibuprofen",
                doseText: "400 mg",
                form: .tablet,
                quantityRemaining: 4,
                quantityUnit: .pills,
                expirationDate: calendar.date(byAdding: .month, value: 14, to: now),
                notes: "Pain relief - do not exceed 3 per day"
            ),

            // 3. Expiring soon (within 30 days)
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Loratadine",
                doseText: "10 mg",
                form: .tablet,
                quantityRemaining: 15,
                quantityUnit: .pills,
                expirationDate: calendar.date(byAdding: .day, value: 18, to: now),
                notes: "Allergy relief - once daily"
            ),

            // 4. Expired
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                name: "Cough Syrup",
                doseText: "15 mg/5 mL",
                form: .syrup,
                quantityRemaining: 60,
                quantityUnit: .ml,
                expirationDate: calendar.date(byAdding: .day, value: -45, to: now),
                notes: "EXPIRED - Dispose properly"
            ),

            // 5. No expiration date, liquid form
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                name: "Eye Drops",
                doseText: "0.5%",
                form: .drops,
                quantityRemaining: 10,
                quantityUnit: .ml,
                expirationDate: nil,
                notes: "Lubricating eye drops - use as needed"
            ),
        ]
    }

    /// Generate demo schedules matching the demo medicines.
    static func makeDemoSchedules() -> [Schedule] {
        return [
            // Amoxicillin: 3x daily
            Schedule(
                medicineId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                dosePerIntake: 1.0,
                frequency: .timesOfDay(["08:00", "14:00", "20:00"]),
                notificationsEnabled: true
            ),

            // Ibuprofen: every 8 hours
            Schedule(
                medicineId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                dosePerIntake: 1.0,
                frequency: .everyXHours(8),
                notificationsEnabled: true
            ),

            // Loratadine: once daily
            Schedule(
                medicineId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                dosePerIntake: 1.0,
                frequency: .timesOfDay(["09:00"]),
                notificationsEnabled: false
            ),
        ]
    }

    /// Generate a few demo dose logs (some taken, some skipped) for today.
    static func makeDemoLogs(schedules: [Schedule]) -> [DoseLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var logs: [DoseLog] = []

        // Amoxicillin 08:00 -- taken
        if let schedule = schedules.first,
           let time = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) {
            logs.append(DoseLog(
                scheduleId: schedule.id,
                medicineId: schedule.medicineId,
                scheduledTime: time,
                status: .taken,
                actionTime: calendar.date(bySettingHour: 8, minute: 5, second: 0, of: today)
            ))
        }

        return logs
    }
```

### 9.3 Bundled Demo Images

Demo mode uses **SF Symbols** rendered as placeholder images rather than bundled photos. This saves significant ZIP space while still demonstrating the image pipeline.

```swift
    /// Create a simple placeholder image from an SF Symbol for demo mode.
    static func makePlaceholderImage(symbol: String, size: CGFloat = 256) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size * 0.4, weight: .light)
        let image = UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(.systemGray3, renderingMode: .alwaysOriginal)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            let imageSize = image?.size ?? .zero
            let origin = CGPoint(
                x: (size - imageSize.width) / 2,
                y: (size - imageSize.height) / 2
            )
            image?.draw(at: origin)
        }
    }
```

### 9.4 Activation and Reset

```swift
    /// Load all demo data into persistence. Sets isDemoMode = true in settings.
    static func activate() async throws {
        let store = JSONStore.shared
        let imgStore = ImageStore.shared

        let medicines = makeDemoMedicines()
        let schedules = makeDemoSchedules()
        let logs = makeDemoLogs(schedules: schedules)

        try await store.save(medicines, to: StoreFile.medicines)
        try await store.save(schedules, to: StoreFile.schedules)
        try await store.save(logs, to: StoreFile.doseLogs)

        var settings = AppSettings.default
        settings.isDemoMode = true
        try await store.save(settings, to: StoreFile.settings)

        // Generate placeholder thumbnails for demo medicines
        let symbolMap: [String: String] = [
            "00000000-0000-0000-0000-000000000001": "capsule.fill",
            "00000000-0000-0000-0000-000000000002": "pill.fill",
            "00000000-0000-0000-0000-000000000003": "pill.fill",
            "00000000-0000-0000-0000-000000000004": "flask.fill",
            "00000000-0000-0000-0000-000000000005": "drop.fill",
        ]

        for medicine in medicines {
            if let symbol = symbolMap[medicine.id.uuidString],
               let placeholder = makePlaceholderImage(symbol: symbol, size: 256),
               let thumbData = placeholder.jpegData(compressionQuality: 0.6),
               let displayPlaceholder = makePlaceholderImage(symbol: symbol, size: 512),
               let displayData = displayPlaceholder.jpegData(compressionQuality: 0.7) {
                _ = try await imgStore.save(
                    displayImageData: displayData,
                    thumbnailData: thumbData,
                    id: medicine.id
                )
            }
        }
    }

    /// Erase all user data and demo data. Returns to clean state.
    static func reset() async throws {
        let store = JSONStore.shared

        try await store.delete(filename: StoreFile.medicines)
        try await store.delete(filename: StoreFile.schedules)
        try await store.delete(filename: StoreFile.doseLogs)

        var settings = AppSettings.default
        settings.isDemoMode = false
        try await store.save(settings, to: StoreFile.settings)

        // Image cleanup: delete all files in Images/ and Thumbnails/
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for subdir in ["Images", "Thumbnails"] {
            let dir = docs.appendingPathComponent(subdir)
            if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        await NotificationManager.shared.cancelAll()
    }
}
```

### 9.5 First-Launch Behavior

On first launch (no `settings.json` exists), the app automatically activates demo mode so judges see a populated inventory immediately. The Welcome screen offers "Explore Demo" (keeps demo data) and "Start Fresh" (calls `reset()`).

---

## 10. File Organization

```
MedShelf.swiftpm/
├── Package.swift                       # SPM manifest (iOSApplication, no external deps)
├── MedShelfApp.swift                   # @main App entry, scenePhase observer
│
├── Models/
│   ├── Medicine.swift                  # Medicine struct
│   ├── Schedule.swift                  # Schedule struct
│   ├── DoseLog.swift                   # DoseLog struct
│   ├── AppSettings.swift               # AppSettings struct
│   ├── Enums.swift                     # MedicineForm, QuantityUnit, ScheduleFrequency,
│   │                                   #   DoseStatus, ExpiryStatus, StockStatus
│   └── DoseInstance.swift              # Transient DoseInstance struct
│
├── ViewModels/
│   ├── InventoryViewModel.swift        # Medicine list CRUD, alert computation
│   ├── ScanViewModel.swift             # OCR flow state, image processing
│   ├── ScheduleViewModel.swift         # Schedule CRUD, dose generation, recording
│   └── SettingsViewModel.swift         # AppSettings, demo mode toggle
│
├── Views/
│   ├── ContentView.swift               # TabView root (Inventory, Today, Scan, Settings)
│   ├── Inventory/
│   │   ├── MedicineListView.swift      # Main inventory list with search/filter
│   │   ├── MedicineRowView.swift       # Single row with thumbnail, alerts
│   │   ├── MedicineDetailView.swift    # Full detail with edit capability
│   │   └── MedicineFormView.swift      # Add/edit form
│   ├── Schedule/
│   │   ├── TodayView.swift             # Today's doses timeline
│   │   ├── DoseRowView.swift           # Single dose instance row
│   │   └── ScheduleEditView.swift      # Create/edit schedule
│   ├── Scan/
│   │   ├── ScanView.swift              # Image acquisition + OCR trigger
│   │   ├── ScanReviewView.swift        # OCR results review + edit
│   │   └── CameraPicker.swift          # UIViewControllerRepresentable for camera
│   ├── Settings/
│   │   └── SettingsView.swift          # Settings + demo mode + about
│   └── Components/
│       ├── AlertBadge.swift            # Expiry/stock status badge
│       ├── ConfidenceBadge.swift       # OCR confidence indicator
│       └── EmptyStateView.swift        # Placeholder for empty lists
│
├── Services/
│   ├── JSONStore.swift                 # Actor: JSON file I/O
│   ├── ImageStore.swift                # Actor: image file I/O
│   ├── OCRManager.swift                # VNRecognizeTextRequest wrapper
│   ├── OCRParser.swift                 # Regex parsing (dose, form, expiry, qty)
│   ├── NotificationManager.swift       # Actor: UNUserNotificationCenter wrapper
│   ├── AlertEngine.swift               # Expiry + stock status computation
│   ├── ScheduleEngine.swift            # Dose instance generation + recording
│   └── DemoDataService.swift           # Demo data generation + activation
│
├── Utilities/
│   ├── ImagePipeline.swift             # Downscaling, JPEG compression
│   └── Extensions.swift                # Date formatting, String helpers
│
└── Resources/
    └── Assets.xcassets/                # App icon, accent color
        ├── AppIcon.appiconset/
        └── AccentColor.colorset/
```

**Notes on structure:**
- All `.swift` files live at the project root level in the filesystem (the `Package.swift` target path is `"."`). The folder names above (`Models/`, `Views/`, etc.) are **group folders** for organizational clarity. Swift Playgrounds treats all `.swift` files in the target path as source.
- `Resources/` is declared in `Package.swift` via `.process("Resources")`.
- No `Sources/` subdirectory is used; the standard App Playground convention places code at root.

---

## 11. Dependencies

### 11.1 External Packages

**None.** The project has zero external SPM dependencies. This is mandatory for SSC: remote packages require internet to resolve and will fail in the offline judging environment.

### 11.2 Apple Frameworks Used

| Framework | Purpose | Import Location |
|---|---|---|
| **SwiftUI** | All UI views, navigation, state management | Views, ViewModels, App |
| **Foundation** | JSON coding, dates, file management, regex | Models, Services, Utilities |
| **Vision** | `VNRecognizeTextRequest` for OCR | OCRManager |
| **PhotosUI** | `PhotosPicker` for image selection | ScanView |
| **UIKit** | `UIImage` processing, `UIImagePickerController` | ImagePipeline, CameraPicker |
| **ImageIO** | `CGImageSource` downsampling | ImagePipeline |
| **UserNotifications** | `UNUserNotificationCenter` scheduling | NotificationManager |

### 11.3 Minimum Deployment Target

- **iOS 17.0 / iPadOS 17.0** -- required for `@Observable` macro.
- Compatible with Swift Playgrounds 4.6+ and Xcode 26+.
- Swift tools version: 5.9 (default for App Playgrounds).

### 11.4 Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MedShelf",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "MedShelf",
            targets: ["AppModule"],
            bundleIdentifier: "com.paola.MedShelf",
            teamIdentifier: "",
            displayVersion: "1.0.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ],
            capabilities: [
                .camera(purposeString: "Camera is used to photograph medicine boxes for inventory")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
```

---

## 12. Performance Budget

### 12.1 ZIP Size

| Component | Estimated Size |
|---|---|
| Swift source code (~30 files) | ~100 KB |
| App icon + accent color assets | ~50 KB |
| Demo placeholder images (SF Symbol renders) | 0 KB (generated at runtime) |
| **Total estimated ZIP** | **~150 KB** |

**Target: <= 15 MB** (leaving 10 MB margin below the 25 MB hard limit for potential future additions such as bundled demo photos or sound effects).

The ZIP will be extremely small because:
- No external frameworks or binaries.
- No bundled CoreML models.
- No bundled photos (demo images generated from SF Symbols at runtime).
- No audio/video assets.

### 12.2 Runtime Image Sizes

| Tier | Max Dimension | JPEG Quality | Target Size | Notes |
|---|---|---|---|---|
| Thumbnail | 256px | 0.6 | <= 50 KB | Used in list rows |
| Display | 512px | 0.7 | <= 200 KB | Used in detail view |
| OCR (in-memory) | 1600px | N/A | ~400 KB in RAM | Never persisted to disk |

### 12.3 Processing Time Targets

| Operation | Target | Notes |
|---|---|---|
| OCR (VNRecognizeTextRequest .accurate) | <= 3 seconds | On A12+ chip; tested with 1600px input |
| Image downscaling (3 tiers) | <= 0.5 seconds | ImageIO CGImageSource, no full decode |
| JSON load (medicines.json) | <= 50 ms | Tens of items, small payload |
| JSON save (atomic write) | <= 50 ms | .atomic write option |
| Alert computation (all medicines) | <= 1 ms | Pure arithmetic, no I/O |
| Dose generation (7-day window) | <= 10 ms | Calendar arithmetic only |

### 12.4 Memory Budget

| Resource | Peak Memory | Notes |
|---|---|---|
| OCR image (1600px CGImage) | ~10 MB | Released after VNImageRequestHandler completes |
| Thumbnail cache (10 UIImages) | ~2 MB | Loaded on-demand for visible rows |
| JSON model arrays | < 1 MB | Tens of items |
| **Peak total** | **~15 MB** | Well within iPad memory limits |

### 12.5 3-Minute Judge Experience Budget

The SSC experience must be compelling within 3 minutes. Recommended flow:

| Time | Action |
|---|---|
| 0:00 -- 0:15 | App launches with demo data. Judge sees populated inventory with color-coded alerts. |
| 0:15 -- 0:45 | Judge explores inventory: taps medicines, sees expiry/stock warnings, views detail. |
| 0:45 -- 1:15 | Judge navigates to "Today" tab, sees dose timeline, taps "Taken" on a dose. |
| 1:15 -- 1:45 | Judge tries Scan: picks a photo (or uses camera), sees OCR parse results, reviews fields. |
| 1:45 -- 2:15 | Judge edits a medicine, changes quantity or expiry, sees alert update in real-time. |
| 2:15 -- 2:45 | Judge visits Settings, sees demo mode toggle, notification status. |
| 2:45 -- 3:00 | Judge returns to inventory, appreciates the overall design and responsiveness. |

---

*End of Technical Specification*
