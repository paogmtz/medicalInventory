import SwiftUI
import Observation

/// Manages the medicine inventory: CRUD operations, search, filter, sort, and alert computation.
@Observable
final class InventoryViewModel {

    // MARK: - Published State

    var medicines: [Medicine] = []
    var searchText: String = ""
    var selectedFilter: MedicineFilter = .all
    var sortOption: MedicineSortOption = .status
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    var toastMessage: String?
    var showToast: Bool = false

    // MARK: - Settings Reference

    var settings: AppSettings = .default

    // MARK: - Computed Properties

    var filteredMedicines: [Medicine] {
        var result = medicines

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { medicine in
                medicine.name.lowercased().contains(query) ||
                medicine.doseText.lowercased().contains(query)
            }
        }

        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .expired:
            result = result.filter { expiryStatus(for: $0) == .expired }
        case .expiringSoon:
            result = result.filter {
                if case .expiringSoon = expiryStatus(for: $0) { return true }
                return false
            }
        case .lowStock:
            result = result.filter { isLowStock($0) }
        case .ok:
            result = result.filter {
                let expiry = expiryStatus(for: $0)
                return expiry == .ok && !isLowStock($0)
            }
        }

        // Apply sort
        switch sortOption {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .expiration:
            result.sort { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
        case .quantity:
            result.sort { $0.quantityRemaining < $1.quantityRemaining }
        case .status:
            result.sort { statusPriority(for: $0) < statusPriority(for: $1) }
        case .dateAdded:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    var needsAttentionMedicines: [Medicine] {
        medicines.filter { medicine in
            let expiry = expiryStatus(for: medicine)
            return expiry == .expired ||
                   (expiry != .ok && expiry != .unknown) ||
                   isLowStock(medicine)
        }
    }

    var expiredCount: Int {
        medicines.filter { expiryStatus(for: $0) == .expired }.count
    }

    var expiringSoonCount: Int {
        medicines.filter {
            if case .expiringSoon = expiryStatus(for: $0) { return true }
            return false
        }.count
    }

    var lowStockCount: Int {
        medicines.filter { isLowStock($0) }.count
    }

    var totalCount: Int {
        medicines.count
    }

    var attentionCount: Int {
        needsAttentionMedicines.count
    }

    var hasAnyAlerts: Bool {
        expiredCount > 0 || expiringSoonCount > 0 || lowStockCount > 0
    }

    var isEmpty: Bool {
        medicines.isEmpty
    }

    // MARK: - Alert Status Computation

    func expiryStatus(for medicine: Medicine) -> ExpiryStatus {
        AlertEngine.expiryStatus(
            expirationDate: medicine.expirationDate,
            warningDays: settings.expiryWarningDays
        )
    }

    func isLowStock(_ medicine: Medicine) -> Bool {
        medicine.quantityRemaining > 0 &&
        medicine.quantityRemaining <= Double(settings.lowStockDays)
    }

    func statusPriority(for medicine: Medicine) -> Int {
        let expiry = expiryStatus(for: medicine)
        switch expiry {
        case .expired: return 0
        case .expiringSoon: return 1
        default: break
        }
        if isLowStock(medicine) { return 2 }
        return 3
    }

    func primaryStatus(for medicine: Medicine) -> MedicineStatus {
        let expiry = expiryStatus(for: medicine)
        switch expiry {
        case .expired:
            return .expired
        case .expiringSoon:
            return .expiringSoon
        default:
            break
        }
        if isLowStock(medicine) {
            return .lowStock
        }
        return .ok
    }

    func allStatuses(for medicine: Medicine) -> [MedicineStatus] {
        var statuses: [MedicineStatus] = []
        let expiry = expiryStatus(for: medicine)
        switch expiry {
        case .expired:
            statuses.append(.expired)
        case .expiringSoon:
            statuses.append(.expiringSoon)
        default:
            break
        }
        if isLowStock(medicine) {
            statuses.append(.lowStock)
        }
        if statuses.isEmpty {
            statuses.append(.ok)
        }
        return statuses
    }

    // MARK: - Data Operations

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedMedicines: [Medicine] = await JSONStore.shared.loadOrDefault(
                [Medicine].self, from: StoreFile.medicines, default: []
            )
            let loadedSettings: AppSettings = await JSONStore.shared.loadOrDefault(
                AppSettings.self, from: StoreFile.settings, default: .default
            )

            await MainActor.run {
                self.medicines = loadedMedicines
                self.settings = loadedSettings
            }
        }
    }

    func addMedicine(_ medicine: Medicine) async {
        medicines.append(medicine)
        await saveMedicines()
        triggerToast("Medication added successfully")
    }

    func updateMedicine(_ medicine: Medicine) async {
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            var updated = medicine
            updated.updatedAt = Date()
            medicines[index] = updated
            await saveMedicines()
            triggerToast("Medication updated")
        }
    }

    func deleteMedicine(_ medicine: Medicine) async {
        medicines.removeAll { $0.id == medicine.id }
        await saveMedicines()

        // Clean up images
        do {
            try await ImageStore.shared.deleteImages(id: medicine.id)
        } catch {
            // Non-critical, log silently
        }

        triggerToast("Medication removed")
    }

    func deleteMedicine(at offsets: IndexSet) async {
        let toDelete = offsets.map { filteredMedicines[$0] }
        for medicine in toDelete {
            medicines.removeAll { $0.id == medicine.id }
            try? await ImageStore.shared.deleteImages(id: medicine.id)
        }
        await saveMedicines()
    }

    func markAsFinished(_ medicine: Medicine) async {
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            medicines[index].quantityRemaining = 0
            medicines[index].updatedAt = Date()
            await saveMedicines()
            triggerToast("Marked as finished")
        }
    }

    func updateQuantity(for medicine: Medicine, newQuantity: Double) async {
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            medicines[index].quantityRemaining = max(0, newQuantity)
            medicines[index].updatedAt = Date()
            await saveMedicines()
        }
    }

    func refreshStatuses() {
        // Force recomputation by touching the settings
        // Statuses are computed dynamically, so this triggers view updates
        let _ = expiredCount
        let _ = expiringSoonCount
        let _ = lowStockCount
    }

    // MARK: - Demo Data

    func loadDemoData() async {
        do {
            try await DemoDataService.activate()
            await loadData()
            triggerToast("8 sample medications loaded")
        } catch {
            triggerError("Failed to load demo data: \(error.localizedDescription)")
        }
    }

    func clearAllData() async {
        do {
            try await DemoDataService.reset()
            await MainActor.run {
                self.medicines = []
            }
            triggerToast("All data cleared")
        } catch {
            triggerError("Failed to clear data: \(error.localizedDescription)")
        }
    }

    // MARK: - Persistence

    private func saveMedicines() async {
        do {
            try await JSONStore.shared.save(medicines, to: StoreFile.medicines)
        } catch {
            triggerError("Could not save. Please try again.")
        }
    }

    // MARK: - Feedback

    func triggerToast(_ message: String) {
        toastMessage = message
        showToast = true
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Image Loading

    func loadThumbnail(for medicine: Medicine) async -> UIImage? {
        guard let filename = medicine.thumbnailFilename else { return nil }
        return await ImageStore.shared.loadThumbnail(filename: filename)
    }

    func loadDisplayImage(for medicine: Medicine) async -> UIImage? {
        guard let filename = medicine.photoFilename else { return nil }
        return await ImageStore.shared.loadImage(filename: filename)
    }

    // MARK: - Medicine Lookup

    func medicine(for id: UUID) -> Medicine? {
        medicines.first { $0.id == id }
    }
}

// MARK: - Supporting Types

enum MedicineFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case expired = "Expired"
    case expiringSoon = "Expiring Soon"
    case lowStock = "Low Stock"
    case ok = "OK"

    var id: String { rawValue }
}

enum MedicineSortOption: String, CaseIterable, Identifiable {
    case status = "Status"
    case name = "Name"
    case expiration = "Expiration"
    case quantity = "Quantity"
    case dateAdded = "Date Added"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .status: return "exclamationmark.circle"
        case .name: return "textformat"
        case .expiration: return "calendar"
        case .quantity: return "number.circle"
        case .dateAdded: return "clock"
        }
    }
}

enum MedicineStatus: String, CaseIterable {
    case expired = "Expired"
    case expiringSoon = "Expiring Soon"
    case lowStock = "Low Stock"
    case ok = "Good"

    var color: Color {
        switch self {
        case .expired: return Color(.systemRed)
        case .expiringSoon: return Color(.systemOrange)
        case .lowStock: return Color(.systemBlue)
        case .ok: return Color(.systemGreen)
        }
    }

    var icon: String {
        switch self {
        case .expired: return "exclamationmark.triangle.fill"
        case .expiringSoon: return "clock.badge.exclamationmark"
        case .lowStock: return "arrow.down.circle.fill"
        case .ok: return "checkmark.circle.fill"
        }
    }
}
