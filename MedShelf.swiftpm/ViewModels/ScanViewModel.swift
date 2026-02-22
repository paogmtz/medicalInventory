import SwiftUI
import PhotosUI
import Observation

/// Manages the OCR scanning flow: image acquisition, processing, parsed results, and review.
@Observable
final class ScanViewModel {

    // MARK: - Flow State

    enum ScanStep: Int, CaseIterable {
        case capture = 1
        case processing = 2
        case review = 3
    }

    var currentStep: ScanStep = .capture
    var isProcessing: Bool = false
    var processingMessage: String = "Analyzing medicine box..."

    // MARK: - Image State

    var selectedImage: UIImage?
    var selectedPhotoItem: PhotosPickerItem?
    var showCamera: Bool = false
    var showPhotoPicker: Bool = false

    // MARK: - OCR Results

    var ocrRawText: String = ""
    var ocrConfidence: Double = 0.0
    var ocrCompleted: Bool = false
    var ocrError: String?

    // MARK: - Editable Fields (populated by OCR or manually)

    var medicineName: String = ""
    var doseText: String = ""
    var selectedForm: MedicineForm = .tablet
    var quantityText: String = "1"
    var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var notes: String = ""

    // MARK: - Confidence Per Field

    var nameConfidence: FieldConfidence = .manual
    var doseConfidence: FieldConfidence = .manual
    var formConfidence: FieldConfidence = .manual
    var expiryConfidence: FieldConfidence = .manual
    var quantityConfidence: FieldConfidence = .manual

    // MARK: - Validation

    var isFormValid: Bool {
        !medicineName.trimmed.isEmpty && !doseText.trimmed.isEmpty
    }

    var quantity: Double {
        Double(quantityText) ?? 1.0
    }

    // MARK: - Camera Availability

    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    // MARK: - Actions

    func reset() {
        currentStep = .capture
        isProcessing = false
        processingMessage = "Analyzing medicine box..."
        selectedImage = nil
        selectedPhotoItem = nil
        ocrRawText = ""
        ocrConfidence = 0.0
        ocrCompleted = false
        ocrError = nil
        medicineName = ""
        doseText = ""
        selectedForm = .tablet
        quantityText = "1"
        expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        notes = ""
        nameConfidence = .manual
        doseConfidence = .manual
        formConfidence = .manual
        expiryConfidence = .manual
        quantityConfidence = .manual
    }

    func skipToManualEntry() {
        currentStep = .review
        ocrCompleted = false
    }

    func handleSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.selectedImage = image
                }
                await processImage(image)
            }
        } catch {
            await MainActor.run {
                self.ocrError = "Failed to load selected photo."
                self.currentStep = .review
            }
        }
    }

    func handleCapturedImage(_ image: UIImage) async {
        await MainActor.run {
            self.selectedImage = image
        }
        await processImage(image)
    }

    func handleDemoImage() async {
        // Generate a demo image from SF Symbol for demonstration
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        let symbol = UIImage(systemName: "pill.fill", withConfiguration: config)?
            .withTintColor(.systemGray3, renderingMode: .alwaysOriginal)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let demoImage = renderer.image { context in
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 400, height: 300)))
            let imageSize = symbol?.size ?? .zero
            let origin = CGPoint(
                x: (400 - imageSize.width) / 2,
                y: (300 - imageSize.height) / 2
            )
            symbol?.draw(at: origin)

            // Draw sample text
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ]
            let sampleText = "Ibuprofen 200 mg\n30 Tablets\nEXP 03/2027"
            (sampleText as NSString).draw(
                in: CGRect(x: 20, y: 220, width: 360, height: 80),
                withAttributes: textAttrs
            )
        }

        await MainActor.run {
            self.selectedImage = demoImage
        }

        // Simulate OCR with pre-filled data for demo
        await MainActor.run {
            self.currentStep = .processing
            self.isProcessing = true
        }

        // Brief delay for visual feedback
        try? await Task.sleep(nanoseconds: 800_000_000)

        await MainActor.run {
            self.medicineName = "Ibuprofen"
            self.nameConfidence = .high
            self.doseText = "200 mg"
            self.doseConfidence = .high
            self.selectedForm = .tablet
            self.formConfidence = .high
            self.quantityText = "30"
            self.quantityConfidence = .high
            if let date = Calendar.current.date(from: DateComponents(year: 2027, month: 3, day: 31)) {
                self.expirationDate = date
                self.expiryConfidence = .high
            }
            self.ocrRawText = "IBUPROFEN 200 mg\n30 Tablets\nEXP 03/2027\nLot: ABC123"
            self.ocrConfidence = 0.92
            self.ocrCompleted = true
            self.isProcessing = false
            self.currentStep = .review
        }
    }

    // MARK: - OCR Processing

    private func processImage(_ image: UIImage) async {
        await MainActor.run {
            self.currentStep = .processing
            self.isProcessing = true
            self.ocrError = nil
        }

        guard let cgImage = image.cgImage else {
            await MainActor.run {
                self.ocrError = "Could not process the image."
                self.isProcessing = false
                self.currentStep = .review
            }
            return
        }

        // Process image through pipeline for storage
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            let _ = ImagePipeline.process(imageData: imageData)
        }

        do {
            let result = try await OCRManager.scan(image: cgImage)

            await MainActor.run {
                self.ocrRawText = result.rawText
                self.ocrConfidence = result.confidence

                if let name = result.suggestedName, !name.isEmpty {
                    self.medicineName = name
                    self.nameConfidence = result.confidence > 0.7 ? .high : .low
                }

                if let dose = result.suggestedDose, !dose.isEmpty {
                    self.doseText = dose
                    self.doseConfidence = result.confidence > 0.7 ? .high : .low
                }

                if let form = result.suggestedForm {
                    self.selectedForm = form
                    self.formConfidence = result.confidence > 0.7 ? .high : .low
                }

                if let expiry = result.suggestedExpiry {
                    self.expirationDate = expiry
                    self.expiryConfidence = result.confidence > 0.7 ? .high : .low
                }

                if let qty = result.suggestedQuantity {
                    self.quantityText = "\(qty)"
                    self.quantityConfidence = result.confidence > 0.7 ? .high : .low
                }

                self.ocrCompleted = true
                self.isProcessing = false
                self.currentStep = .review
            }
        } catch {
            await MainActor.run {
                self.ocrError = "Could not read text from the image. Please enter details manually."
                self.isProcessing = false
                self.currentStep = .review
            }
        }
    }

    // MARK: - Build Medicine

    func buildMedicine() -> Medicine {
        Medicine(
            name: medicineName.trimmed,
            doseText: doseText.trimmed,
            form: selectedForm,
            quantityRemaining: quantity,
            quantityUnit: selectedForm.defaultUnit,
            expirationDate: expirationDate,
            ocrRawText: ocrRawText.nilIfEmpty,
            ocrConfidence: ocrCompleted ? ocrConfidence : nil,
            notes: notes.nilIfEmpty
        )
    }

    /// Save processed images and return updated medicine with filenames
    func saveMedicineWithImages(_ medicine: Medicine) async -> Medicine {
        var updated = medicine
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.9) else {
            return updated
        }

        if let processed = ImagePipeline.process(imageData: imageData) {
            do {
                let filenames = try await ImageStore.shared.save(
                    displayImageData: processed.displayJPEG,
                    thumbnailData: processed.thumbnailJPEG,
                    id: medicine.id
                )
                updated.photoFilename = filenames.photo
                updated.thumbnailFilename = filenames.thumbnail
            } catch {
                // Non-critical; medicine saves without images
            }
        }

        return updated
    }
}

// MARK: - Field Confidence

enum FieldConfidence {
    case high       // > 80% OCR confidence
    case low        // < 80% OCR confidence
    case manual     // User entered manually

    var icon: String? {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .low: return "questionmark.diamond"
        case .manual: return nil
        }
    }

    var color: Color {
        switch self {
        case .high: return Color(.systemGreen)
        case .low: return Color(.systemOrange)
        case .manual: return .clear
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .high: return "Automatically detected with high confidence"
        case .low: return "Automatically detected with low confidence, please verify"
        case .manual: return "Manually entered"
        }
    }
}

// MARK: - MedicineForm Default Unit

extension MedicineForm {
    var defaultUnit: QuantityUnit {
        switch self {
        case .syrup, .drops: return .ml
        case .cream: return .g
        case .injection: return .ml
        default: return .pills
        }
    }
}
