import SwiftUI

/// Full detail view for a single medicine showing hero image, all fields, status cards,
/// schedule information, dose log history, and action buttons.
struct MedicineDetailView: View {
    let medicine: Medicine
    @Bindable var inventoryVM: InventoryViewModel
    @Bindable var scheduleVM: ScheduleViewModel
    @Bindable var settingsVM: SettingsViewModel

    @State private var displayImage: UIImage?
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showScheduleEdit = false
    @State private var showMarkFinishedConfirm = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentMedicine: Medicine {
        inventoryVM.medicine(for: medicine.id) ?? medicine
    }

    private var primaryStatus: MedicineStatus {
        inventoryVM.primaryStatus(for: currentMedicine)
    }

    private var allStatuses: [MedicineStatus] {
        inventoryVM.allStatuses(for: currentMedicine)
    }

    private var schedule: Schedule? {
        scheduleVM.schedule(for: medicine.id)
    }

    private var recentLogs: [DoseLog] {
        scheduleVM.doseLogs(for: medicine.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero image
                heroImageSection

                // Name and subtitle
                nameSection

                // Status cards
                statusSection

                // Details card
                detailsCard

                // Schedule section
                scheduleSection

                // Dose log
                doseLogSection

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Medication Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .accessibilityLabel("Edit medication")
                .accessibilityHint("Opens the edit form for this medication")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            MedicineFormView(
                inventoryVM: inventoryVM,
                existingMedicine: currentMedicine
            )
        }
        .sheet(isPresented: $showScheduleEdit) {
            ScheduleEditView(
                medicine: currentMedicine,
                scheduleVM: scheduleVM,
                existingSchedule: schedule
            )
        }
        .confirmationDialog("Delete Medication", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    await inventoryVM.deleteMedicine(currentMedicine)
                    await scheduleVM.deleteAllSchedules(for: medicine.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(currentMedicine.name)? This cannot be undone.")
        }
        .confirmationDialog("Mark as Finished", isPresented: $showMarkFinishedConfirm) {
            Button("Mark as Finished") {
                Task {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    await inventoryVM.markAsFinished(currentMedicine)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will set the quantity to 0. The medication record will be kept for your history.")
        }
        .task {
            await loadImage()
        }
    }

    // MARK: - Hero Image

    private var heroImageSection: some View {
        Group {
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Photo of \(currentMedicine.name)")
            } else {
                ZStack {
                    Color.accentColor.opacity(0.08)

                    Image(systemName: currentMedicine.form.sfSymbol)
                        .font(.system(size: 60))
                        .foregroundStyle(.accentColor.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentMedicine.name)
                .font(.title)
                .fontWeight(.bold)

            if let notes = currentMedicine.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            ForEach(allStatuses, id: \.self) { status in
                StatusCard(
                    status: status,
                    medicine: currentMedicine,
                    settings: settingsVM.settings
                )
            }
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DETAILS")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                detailRow(
                    label: "Form",
                    icon: currentMedicine.form.sfSymbol,
                    value: currentMedicine.form.displayName
                )
                Divider()

                detailRow(label: "Dose", value: currentMedicine.doseText)
                Divider()

                detailRow(
                    label: "Quantity",
                    value: "\(currentMedicine.quantityRemaining.formattedQuantity) \(currentMedicine.quantityUnit.displayName) remaining"
                )
                Divider()

                if let expDate = currentMedicine.expirationDate {
                    detailRow(label: "Expiration", value: expDate.formattedMedium)
                    Divider()
                }

                detailRow(label: "Added", value: currentMedicine.createdAt.formattedMedium)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func detailRow(label: String, icon: String? = nil, value: String) -> some View {
        HStack {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SCHEDULE")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showScheduleEdit = true
                } label: {
                    Text(schedule != nil ? "Edit" : "Add")
                        .font(.subheadline)
                }
            }

            if let schedule {
                VStack(alignment: .leading, spacing: 8) {
                    Text(schedule.frequency.displayText)
                        .font(.body)

                    Text("\(schedule.dosePerIntake.formattedQuantity) \(currentMedicine.quantityUnit.displayName) per dose")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if schedule.notificationsEnabled {
                        Label("Notifications enabled", systemImage: "bell.badge.fill")
                            .font(.footnote)
                            .foregroundStyle(.accentColor)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                InlineEmptyState(
                    icon: "clock.badge.questionmark",
                    title: "No schedule set",
                    subtitle: "Add a dosing schedule to track when to take this medication.",
                    ctaTitle: "Add Schedule",
                    ctaAction: { showScheduleEdit = true }
                )
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Dose Log Section

    private var doseLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT DOSE LOG")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if recentLogs.isEmpty {
                InlineEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No doses recorded yet",
                    subtitle: "Dose history will appear here as you track your daily intake."
                )
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(recentLogs) { log in
                        doseLogRow(log)
                        if log.id != recentLogs.last?.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func doseLogRow(_ log: DoseLog) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.scheduledTime.formattedMedium)
                    .font(.subheadline)

                Text(log.scheduledTime.formattedTime)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: log.status == .taken ? "checkmark.circle.fill" : "forward.circle.fill")
                    .foregroundStyle(log.status == .taken ? Color(.systemGreen) : Color(.systemOrange))

                Text(log.status == .taken ? "Taken" : "Skipped")
                    .font(.subheadline)
                    .foregroundStyle(log.status == .taken ? Color(.systemGreen) : Color(.systemOrange))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(log.scheduledTime.formattedMedium) at \(log.scheduledTime.formattedTime), \(log.status.rawValue)")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if currentMedicine.quantityRemaining > 0 {
                Button {
                    showMarkFinishedConfirm = true
                } label: {
                    Label("Mark as Finished", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.accentColor)
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Medication", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.red)
            .accessibilityLabel("Delete medication")
            .accessibilityHint("Permanently removes this medication from your inventory")
        }
        .padding(.top, 8)
    }

    // MARK: - Image Loading

    private func loadImage() async {
        if let img = await inventoryVM.loadDisplayImage(for: medicine) {
            await MainActor.run {
                self.displayImage = img
            }
        }
    }
}
