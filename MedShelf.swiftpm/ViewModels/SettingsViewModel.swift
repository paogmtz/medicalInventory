import SwiftUI
import Observation

/// Manages application settings, demo mode, and preferences.
@Observable
final class SettingsViewModel {

    // MARK: - Settings State

    var settings: AppSettings = .default
    var isLoadingDemo: Bool = false
    var showClearConfirmation: Bool = false
    var showDemoLoadConfirmation: Bool = false
    var showPrivacySheet: Bool = false
    var showSafetySheet: Bool = false
    var showAboutSheet: Bool = false
    var toastMessage: String?
    var showToast: Bool = false

    // MARK: - Computed Properties

    var expiryWarningDays: Int {
        get { settings.expiryWarningDays }
        set {
            settings.expiryWarningDays = newValue
            Task { await saveSettings() }
        }
    }

    var lowStockDays: Int {
        get { settings.lowStockDays }
        set {
            settings.lowStockDays = newValue
            Task { await saveSettings() }
        }
    }

    var isDemoMode: Bool {
        get { settings.isDemoMode }
        set {
            settings.isDemoMode = newValue
            Task { await saveSettings() }
        }
    }

    // MARK: - Data Operations

    func loadSettings() async {
        let loaded = await JSONStore.shared.loadOrDefault(
            AppSettings.self,
            from: StoreFile.settings,
            default: .default
        )
        await MainActor.run {
            self.settings = loaded
        }
    }

    func saveSettings() async {
        do {
            try await JSONStore.shared.save(settings, to: StoreFile.settings)
        } catch {
            // Settings save failure is non-critical
        }
    }

    func loadDemoData(inventoryVM: InventoryViewModel, scheduleVM: ScheduleViewModel) async {
        isLoadingDemo = true
        defer { isLoadingDemo = false }

        do {
            try await DemoDataService.activate()
            settings.isDemoMode = true
            await saveSettings()
            await inventoryVM.loadData()
            await scheduleVM.loadData()
            triggerToast("8 sample medications loaded")
        } catch {
            triggerToast("Failed to load demo data")
        }
    }

    func clearAllData(inventoryVM: InventoryViewModel, scheduleVM: ScheduleViewModel) async {
        do {
            try await DemoDataService.reset()
            settings.isDemoMode = false
            await saveSettings()
            await inventoryVM.loadData()
            await scheduleVM.loadData()
            triggerToast("All data cleared")
        } catch {
            triggerToast("Failed to clear data")
        }
    }

    // MARK: - Sync settings to other ViewModels

    func syncToInventory(_ inventoryVM: InventoryViewModel) {
        inventoryVM.settings = settings
    }

    // MARK: - Feedback

    private func triggerToast(_ message: String) {
        toastMessage = message
        showToast = true
    }

    // MARK: - Static Content

    static let privacyNotice = """
    Privacy Notice

    MedShelf stores all your data locally on this device. Your medication \
    information never leaves your device and is never transmitted to any \
    server, cloud service, or third party.

    No account is required. No personal information is collected. No \
    analytics or tracking of any kind is included in this app.

    Photos you scan are processed entirely on-device using Apple's Vision \
    framework. They are never uploaded to any server.

    Your data is yours alone.

    If you delete the app, all stored data is permanently removed.
    """

    static let safetyDisclaimer = """
    Safety Disclaimer

    MedShelf is a personal organization tool. It is not a medical device \
    and does not provide medical advice, diagnosis, or treatment \
    recommendations.

    Always consult a qualified healthcare professional before starting, \
    stopping, or changing any medication. Do not rely solely on this app \
    for medication management decisions.

    Expiration date alerts are based on information you enter and may not \
    reflect the actual condition of your medications. When in doubt, \
    consult your pharmacist.

    If you are experiencing a medical emergency, call your local emergency \
    number immediately.
    """

    static let availableExpiryDays = [7, 14, 30, 60, 90]
    static let availableLowStockDays = [3, 5, 7, 14, 30]
}
