import SwiftUI

/// Add or edit form for medicine fields. Used for manual entry and editing existing medicines.
struct MedicineFormView: View {
    @Bindable var inventoryVM: InventoryViewModel
    var existingMedicine: Medicine?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var name: String = ""
    @State private var doseText: String = ""
    @State private var form: MedicineForm = .tablet
    @State private var quantityText: String = "1"
    @State private var quantityUnit: QuantityUnit = .pills
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var isSaving: Bool = false

    private var isEditing: Bool {
        existingMedicine != nil
    }

    private var isFormValid: Bool {
        !name.trimmed.isEmpty && !doseText.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Medication Details") {
                    TextField("Name *", text: $name)
                        .accessibilityLabel("Medication name, required")

                    Picker("Form", selection: $form) {
                        ForEach(MedicineForm.allCases, id: \.self) { medicineForm in
                            Label(medicineForm.displayName, systemImage: medicineForm.sfSymbol)
                                .tag(medicineForm)
                        }
                    }
                    .accessibilityLabel("Medication form")

                    TextField("Dose (e.g., 200 mg) *", text: $doseText)
                        .accessibilityLabel("Dose amount, required")
                }

                // Quantity
                Section("Quantity") {
                    HStack {
                        TextField("Amount", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)

                        Picker("Unit", selection: $quantityUnit) {
                            ForEach(QuantityUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } footer: {
                    Text("How much you currently have on hand.")
                }

                // Expiration
                Section("Expiration Date") {
                    DatePicker(
                        "Expires",
                        selection: $expirationDate,
                        displayedComponents: .date
                    )
                } footer: {
                    Text("Check the packaging for the expiration date. Medications past this date may lose effectiveness.")
                }

                // Notes
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Notes, optional")
                } footer: {
                    Text("Add any helpful information like instructions or purpose.")
                }
            }
            .navigationTitle(isEditing ? "Edit Medication" : "Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isSaving)
                    .accessibilityLabel("Save medication")
                    .accessibilityHint("Saves this medication to your inventory")
                }
            }
            .onAppear {
                loadExisting()
            }
        }
    }

    // MARK: - Load Existing

    private func loadExisting() {
        guard let medicine = existingMedicine else { return }
        name = medicine.name
        doseText = medicine.doseText
        form = medicine.form
        quantityText = medicine.quantityRemaining.formattedQuantity
        quantityUnit = medicine.quantityUnit
        if let expDate = medicine.expirationDate {
            expirationDate = expDate
        }
        notes = medicine.notes ?? ""
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if var existing = existingMedicine {
            existing.name = name.trimmed
            existing.doseText = doseText.trimmed
            existing.form = form
            existing.quantityRemaining = Double(quantityText) ?? 0
            existing.quantityUnit = quantityUnit
            existing.expirationDate = expirationDate
            existing.notes = notes.nilIfEmpty
            existing.updatedAt = Date()

            await inventoryVM.updateMedicine(existing)
        } else {
            let medicine = Medicine(
                name: name.trimmed,
                doseText: doseText.trimmed,
                form: form,
                quantityRemaining: Double(quantityText) ?? 0,
                quantityUnit: quantityUnit,
                expirationDate: expirationDate,
                notes: notes.nilIfEmpty
            )

            await inventoryVM.addMedicine(medicine)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
