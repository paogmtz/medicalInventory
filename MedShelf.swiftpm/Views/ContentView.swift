import SwiftUI

/// Root view of MedShelf with a 3-tab navigation: Today, Medications, Settings.
struct ContentView: View {
    @State var inventoryVM: InventoryViewModel
    @State var scheduleVM: ScheduleViewModel
    @State var settingsVM: SettingsViewModel

    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                inventoryVM: inventoryVM,
                scheduleVM: scheduleVM,
                settingsVM: settingsVM
            )
            .tabItem {
                Label("Today", systemImage: "heart.text.clipboard")
            }
            .tag(AppTab.today)
            .badge(inventoryVM.expiredCount > 0 ? "!" : nil)

            MedicineListView(
                inventoryVM: inventoryVM,
                scheduleVM: scheduleVM,
                settingsVM: settingsVM
            )
            .tabItem {
                Label("Meds", systemImage: "pills.fill")
            }
            .tag(AppTab.medications)
            .badge(inventoryVM.attentionCount > 0 ? inventoryVM.attentionCount : 0)

            SettingsView(
                settingsVM: settingsVM,
                inventoryVM: inventoryVM,
                scheduleVM: scheduleVM
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
        .tint(.accentColor)
    }
}

enum AppTab: String, Hashable {
    case today
    case medications
    case settings
}
