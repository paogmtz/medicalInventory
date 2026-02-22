import SwiftUI

/// MedShelf: A home medication inventory tracker.
/// Surfaces expired items, low-stock warnings, and upcoming doses
/// so nothing goes to waste and no one misses a dose.
@main
struct MedShelfApp: App {
    @State private var inventoryVM = InventoryViewModel()
    @State private var scheduleVM = ScheduleViewModel()
    @State private var settingsVM = SettingsViewModel()

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasLoadedInitialData = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                inventoryVM: inventoryVM,
                scheduleVM: scheduleVM,
                settingsVM: settingsVM
            )
            .task {
                guard !hasLoadedInitialData else { return }
                hasLoadedInitialData = true
                await loadAllData()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    Task {
                        // Refresh statuses when returning to foreground
                        // (dates may have changed while app was backgrounded)
                        await settingsVM.loadSettings()
                        settingsVM.syncToInventory(inventoryVM)
                        inventoryVM.refreshStatuses()
                        scheduleVM.regenerateTodaysDoses()

                        // Reschedule notifications
                        await scheduleVM.rescheduleNotifications(
                            medicines: inventoryVM.medicines
                        )
                    }
                }
            }
        }
    }

    /// Load all persisted data on app launch.
    private func loadAllData() async {
        await settingsVM.loadSettings()
        settingsVM.syncToInventory(inventoryVM)
        await inventoryVM.loadData()
        await scheduleVM.loadData()
    }
}
