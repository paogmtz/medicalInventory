import SwiftUI

/// Grid/list display of all medicines with search, sort, filter, and empty state.
struct MedicineListView: View {
    @Bindable var inventoryVM: InventoryViewModel
    @Bindable var scheduleVM: ScheduleViewModel
    @Bindable var settingsVM: SettingsViewModel

    @State private var showAddMedication = false
    @State private var selectedMedicine: Medicine?
    @State private var showDeleteConfirm = false
    @State private var medicineToDelete: Medicine?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilitySize: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
    ]

    private let singleColumn = [
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            Group {
                if inventoryVM.isEmpty && inventoryVM.searchText.isEmpty {
                    emptyState
                } else {
                    medicineGrid
                }
            }
            .navigationTitle("Medications")
            .searchable(
                text: $inventoryVM.searchText,
                prompt: "Search medications..."
            )
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

                ToolbarItem(placement: .secondaryAction) {
                    sortMenu
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
            .confirmationDialog(
                "Delete Medication",
                isPresented: $showDeleteConfirm,
                presenting: medicineToDelete
            ) { medicine in
                Button("Delete", role: .destructive) {
                    Task {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        await inventoryVM.deleteMedicine(medicine)
                        await scheduleVM.deleteAllSchedules(for: medicine.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { medicine in
                Text("Are you sure you want to delete \(medicine.name)? This cannot be undone.")
            }
        }
    }

    // MARK: - Medicine Grid

    private var medicineGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Filter chips
                filterChips

                // Needs attention section
                if !inventoryVM.needsAttentionMedicines.isEmpty &&
                   inventoryVM.selectedFilter == .all &&
                   inventoryVM.searchText.isEmpty {
                    needsAttentionSection
                }

                // All medications
                allMedicationsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            await inventoryVM.loadData()
            settingsVM.syncToInventory(inventoryVM)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MedicineFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            inventoryVM.selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(inventoryVM.selectedFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                inventoryVM.selectedFilter == filter
                                    ? Color.accentColor.opacity(0.15)
                                    : Color(.tertiarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                inventoryVM.selectedFilter == filter
                                    ? .accentColor
                                    : .primary
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter: \(filter.rawValue)")
                    .accessibilityAddTraits(inventoryVM.selectedFilter == filter ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Needs Attention Section

    private var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEEDS ATTENTION (\(inventoryVM.attentionCount))")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: isAccessibilitySize ? singleColumn : columns, spacing: 12) {
                ForEach(inventoryVM.needsAttentionMedicines) { medicine in
                    medicineCard(medicine)
                }
            }
        }
    }

    // MARK: - All Medications Section

    private var allMedicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if inventoryVM.filteredMedicines.isEmpty && !inventoryVM.searchText.isEmpty {
                searchEmptyState
            } else {
                let sectionTitle = inventoryVM.selectedFilter == .all
                    ? "ALL MEDICATIONS (\(inventoryVM.filteredMedicines.count))"
                    : "\(inventoryVM.selectedFilter.rawValue.uppercased()) (\(inventoryVM.filteredMedicines.count))"

                Text(sectionTitle)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: isAccessibilitySize ? singleColumn : columns, spacing: 12) {
                    ForEach(inventoryVM.filteredMedicines) { medicine in
                        medicineCard(medicine)
                    }
                }
            }
        }
    }

    // MARK: - Medicine Card

    private func medicineCard(_ medicine: Medicine) -> some View {
        Button {
            selectedMedicine = medicine
        } label: {
            MedicineRowView(
                medicine: medicine,
                status: inventoryVM.primaryStatus(for: medicine),
                inventoryVM: inventoryVM
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                selectedMedicine = medicine
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
            Divider()
            Button(role: .destructive) {
                medicineToDelete = medicine
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(cardAccessibilityLabel(for: medicine))
        .accessibilityHint("Double tap to view details")
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $inventoryVM.sortOption) {
                ForEach(MedicineSortOption.allCases) { option in
                    Label(option.rawValue, systemImage: option.icon)
                        .tag(option)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down.circle")
        }
        .accessibilityLabel("Sort medications")
        .accessibilityHint("Choose how to sort the medication list")
    }

    // MARK: - Empty States

    private var emptyState: some View {
        EmptyStateView(
            icon: "pills.circle",
            title: "Your medicine cabinet is empty",
            subtitle: "Add your first medication by scanning the box or entering the details manually.",
            ctaTitle: "Add Your First Medication",
            ctaAction: { showAddMedication = true },
            secondaryCtaTitle: "Load Demo Data",
            secondaryCtaAction: {
                Task {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    await settingsVM.loadDemoData(
                        inventoryVM: inventoryVM,
                        scheduleVM: scheduleVM
                    )
                }
            }
        )
    }

    private var searchEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No results for \"\(inventoryVM.searchText)\"")
                .font(.headline)

            Text("Try a different search term or check the spelling.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func cardAccessibilityLabel(for medicine: Medicine) -> String {
        let status = inventoryVM.primaryStatus(for: medicine)
        let qty = medicine.quantityRemaining.formattedQuantity
        return "\(medicine.name), \(medicine.form.displayName), \(medicine.doseText), \(qty) remaining, status: \(status.rawValue)"
    }
}
