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
