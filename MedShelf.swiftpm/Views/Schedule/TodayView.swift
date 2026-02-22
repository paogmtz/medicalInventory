import SwiftUI

/// Today Dashboard showing alert chips, upcoming doses grouped by time period,
/// quick stats, and medications needing attention.
struct TodayView: View {
    @Bindable var inventoryVM: InventoryViewModel
    @Bindable var scheduleVM: ScheduleViewModel
    @Bindable var settingsVM: SettingsViewModel

    @State private var showAddMedication = false
    @State private var selectedMedicine: Medicine?
    @State private var showAlerts = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with greeting
                    headerSection

                    // Alert chips
                    if inventoryVM.hasAnyAlerts {
                        alertChipsSection
                    }

                    // Quick stats
                    quickStatsSection

                    // Dose cards grouped by time period
                    if scheduleVM.hasDosesToday {
                        doseListSection
                    } else {
                        noDosesSection
                    }

                    // Medications needing attention
                    if !inventoryVM.needsAttentionMedicines.isEmpty {
                        attentionSection
                    }

                    // Load demo data button (when empty)
                    if inventoryVM.isEmpty {
                        demoDataSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddMedication = true
                    } label: {
                        Label("Add Medication", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add medication")
                    .accessibilityHint("Opens the add medication form")
                }
            }
            .sheet(isPresented: $showAddMedication) {
                ScanView(inventoryVM: inventoryVM, scheduleVM: scheduleVM)
            }
            .navigationDestination(item: $selectedMedicine) { medicine in
                MedicineDetailView(
                    medicine: medicine,
                    inventoryVM: inventoryVM,
                    scheduleVM: scheduleVM,
                    settingsVM: settingsVM
                )
            }
            .refreshable {
                await refreshData()
            }
            .onAppear {
                showAlerts = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.greeting)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(Date().formattedDayAndDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Alert Chips

    private var alertChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if inventoryVM.expiredCount > 0 {
                    AlertChip(
                        status: .expired,
                        count: inventoryVM.expiredCount
                    ) {
                        inventoryVM.selectedFilter = .expired
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }

                if inventoryVM.expiringSoonCount > 0 {
                    AlertChip(
                        status: .expiringSoon,
                        count: inventoryVM.expiringSoonCount
                    ) {
                        inventoryVM.selectedFilter = .expiringSoon
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }

                if inventoryVM.lowStockCount > 0 {
                    AlertChip(
                        status: .lowStock,
                        count: inventoryVM.lowStockCount
                    ) {
                        inventoryVM.selectedFilter = .lowStock
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: showAlerts)
        }
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "pills.fill",
                value: "\(inventoryVM.totalCount)",
                label: "Medications"
            )

            Divider()
                .frame(height: 40)

            statItem(
                icon: "exclamationmark.circle.fill",
                value: "\(inventoryVM.attentionCount)",
                label: "Need Attention",
                pulseIfPositive: true
            )

            Divider()
                .frame(height: 40)

            statItem(
                icon: "checkmark.circle.fill",
                value: "\(scheduleVM.takenTodayCount)",
                label: "Taken Today"
            )
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(icon: String, value: String, label: String, pulseIfPositive: Bool = false) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, isActive: pulseIfPositive && (Int(value) ?? 0) > 0)

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Dose List

    private var doseListSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(scheduleVM.dosesByPeriod, id: \.period) { group in
                VStack(alignment: .leading, spacing: 12) {
                    // Period header
                    HStack {
                        Text(group.period.uppercased())
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let firstTime = group.doses.first?.scheduledTime {
                            Text(firstTime.formattedTime)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(group.doses) { dose in
                        DoseRowView(
                            dose: dose,
                            medicine: inventoryVM.medicine(for: dose.medicineId),
                            onTaken: {
                                await markDose(dose, status: .taken)
                            },
                            onSkip: {
                                await markDose(dose, status: .skipped)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - No Doses

    private var noDosesSection: some View {
        VStack(spacing: 12) {
            if inventoryVM.isEmpty {
                EmptyStateView(
                    icon: "pills.circle",
                    title: "Your shelf is empty",
                    subtitle: "Add your first medication to start tracking expiration dates and inventory.",
                    ctaTitle: "Add Medication",
                    ctaAction: { showAddMedication = true }
                )
                .frame(minHeight: 300)
            } else {
                InlineEmptyState(
                    icon: "calendar.badge.checkmark",
                    title: "All clear for today!",
                    subtitle: "No doses are scheduled for today. Enjoy your day, or open a medication to set up reminders."
                )
            }
        }
    }

    // MARK: - Attention Section

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEEDS ATTENTION")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(inventoryVM.needsAttentionMedicines) { medicine in
                Button {
                    selectedMedicine = medicine
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: medicine.form.sfSymbol)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(medicine.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(medicine.doseText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        AlertBadge(status: inventoryVM.primaryStatus(for: medicine))

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(medicine.name), \(medicine.doseText), \(inventoryVM.primaryStatus(for: medicine).rawValue)")
                .accessibilityHint("Double tap to view details")
            }
        }
    }

    // MARK: - Demo Data

    private var demoDataSection: some View {
        VStack(spacing: 12) {
            Divider()

            Button {
                Task {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    await settingsVM.loadDemoData(
                        inventoryVM: inventoryVM,
                        scheduleVM: scheduleVM
                    )
                }
            } label: {
                Label("Load Demo Data", systemImage: "tray.and.arrow.down.fill")
                    .font(.body)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(settingsVM.isLoadingDemo)
            .accessibilityLabel("Load demo data")
            .accessibilityHint("Loads sample medications to explore the app")
        }
    }

    // MARK: - Actions

    private func markDose(_ dose: DoseInstance, status: DoseStatus) async {
        await scheduleVM.recordDose(
            instance: dose,
            status: status,
            inventoryVM: inventoryVM
        )
    }

    private func refreshData() async {
        await inventoryVM.loadData()
        await scheduleVM.loadData()
        settingsVM.syncToInventory(inventoryVM)
    }
}
