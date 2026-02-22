import SwiftUI

/// OCR results review screen with editable fields, confidence indicators,
/// and raw recognized text. Step 3 of the Add Medication flow.
struct ScanReviewView: View {
    @Bindable var scanVM: ScanViewModel
    @Bindable var inventoryVM: InventoryViewModel
    @Bindable var scheduleVM: ScheduleViewModel
    var onDismiss: () -> Void

    @State private var showRawText = false
    @State private var isSaving = false
    @State private var showRetakeOptions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image preview (if available)
                if scanVM.selectedImage != nil {
                    imagePreviewSection
                }

                // OCR error banner
                if let error = scanVM.ocrError {
                    ocrErrorBanner(error)
                }

                // Overall confidence
                if scanVM.ocrCompleted {
                    OverallConfidenceBadge(confidence: scanVM.ocrConfidence)
                }

                // Form fields
                formFieldsSection

                // Recognized text (collapsible)
                if scanVM.ocrCompleted && !scanVM.ocrRawText.isEmpty {
                    recognizedTextSection
                }

                // Save button
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Image Preview

    private var imagePreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCANNED IMAGE")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack {
                if let image = scanVM.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Button {
                    showRetakeOptions = true
                } label: {
                    Label("Retake", systemImage: "camera.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .confirmationDialog("Retake Photo", isPresented: $showRetakeOptions) {
            if scanVM.isCameraAvailable {
                Button("Take New Photo") {
                    scanVM.reset()
                    scanVM.showCamera = true
                }
            }
            Button("Choose from Library") {
                scanVM.reset()
                scanVM.showPhotoPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - OCR Error Banner

    private func ocrErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Color(.systemOrange))

            VStack(alignment: .leading, spacing: 2) {
                Text("Could not read the text")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemOrange).opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: \(message)")
    }

    // MARK: - Form Fields

    private var formFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MEDICATION DETAILS")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                // Name
                formField(
                    label: "Name *",
                    text: $scanVM.medicineName,
                    confidence: scanVM.nameConfidence,
                    accessibilityLabel: "Medication name, required"
                )
                Divider().padding(.horizontal, 16)

                // Form picker
                HStack {
                    Text("Form")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Form", selection: $scanVM.selectedForm) {
                        ForEach(MedicineForm.allCases, id: \.self) { form in
                            Label(form.displayName, systemImage: form.sfSymbol)
                                .tag(form)
                        }
                    }
                    .labelsHidden()

                    if let icon = scanVM.formConfidence.icon {
                        ConfidenceBadge(confidence: scanVM.formConfidence)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityLabel("Medication form")

                Divider().padding(.horizontal, 16)

                // Dose
                formField(
                    label: "Dose *",
                    text: $scanVM.doseText,
                    confidence: scanVM.doseConfidence,
                    accessibilityLabel: "Dose amount, required"
                )
                Divider().padding(.horizontal, 16)

                // Quantity
                formField(
                    label: "Quantity *",
                    text: $scanVM.quantityText,
                    confidence: scanVM.quantityConfidence,
                    keyboard: .decimalPad,
                    accessibilityLabel: "Quantity on hand"
                )
                Divider().padding(.horizontal, 16)

                // Expiration date
                HStack {
                    Text("Expiration Date *")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $scanVM.expirationDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    if let icon = scanVM.expiryConfidence.icon {
                        ConfidenceBadge(confidence: scanVM.expiryConfidence)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityLabel("Expiration date")

                Divider().padding(.horizontal, 16)

                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    TextField("Optional notes (e.g., take with food)", text: $scanVM.notes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formField(
        label: String,
        text: Binding<String>,
        confidence: FieldConfidence,
        keyboard: UIKeyboardType = .default,
        accessibilityLabel: String
    ) -> some View {
        HStack {
            TextField(label, text: text)
                .font(.body)
                .keyboardType(keyboard)
                .accessibilityLabel(accessibilityLabel)

            if let _ = confidence.icon {
                ConfidenceBadge(confidence: confidence)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Recognized Text

    private var recognizedTextSection: some View {
        DisclosureGroup("Recognized Text", isExpanded: $showRawText) {
            Text(scanVM.ocrRawText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 8)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .tint(.secondary)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await saveMedicine() }
        } label: {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            } else {
                Text("Save Medication")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.accentColor)
        .disabled(!scanVM.isFormValid || isSaving)
        .accessibilityLabel("Save medication")
        .accessibilityHint("Saves this medication to your inventory")
    }

    // MARK: - Save Action

    private func saveMedicine() async {
        isSaving = true
        defer { isSaving = false }

        var medicine = scanVM.buildMedicine()

        // Save images if available
        if scanVM.selectedImage != nil {
            medicine = await scanVM.saveMedicineWithImages(medicine)
        }

        await inventoryVM.addMedicine(medicine)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onDismiss()
    }
}
