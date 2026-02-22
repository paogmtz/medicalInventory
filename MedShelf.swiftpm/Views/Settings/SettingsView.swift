import SwiftUI

/// Settings form with alert thresholds, demo mode toggle, about info, and credits.
struct SettingsView: View {
    @Bindable var settingsVM: SettingsViewModel
    @Bindable var inventoryVM: InventoryViewModel
    @Bindable var scheduleVM: ScheduleViewModel

    var body: some View {
        NavigationStack {
            Form {
                // Alert Thresholds
                alertThresholdsSection

                // Demo section
                demoSection

                // About section
                aboutSection

                // Safety disclaimer
                safetySection

                // Footer
                footerSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $settingsVM.showPrivacySheet) {
                privacySheet
            }
            .sheet(isPresented: $settingsVM.showSafetySheet) {
                safetySheet
            }
            .sheet(isPresented: $settingsVM.showAboutSheet) {
                aboutSheet
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $settingsVM.showClearConfirmation
            ) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        await settingsVM.clearAllData(
                            inventoryVM: inventoryVM,
                            scheduleVM: scheduleVM
                        )
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all medications, schedules, and dose history. This cannot be undone.")
            }
            .onChange(of: settingsVM.settings.expiryWarningDays) { _, _ in
                settingsVM.syncToInventory(inventoryVM)
            }
            .onChange(of: settingsVM.settings.lowStockDays) { _, _ in
                settingsVM.syncToInventory(inventoryVM)
            }
        }
    }

    // MARK: - Alert Thresholds

    private var alertThresholdsSection: some View {
        Section {
            Picker("Expiry Warning", selection: Binding(
                get: { settingsVM.expiryWarningDays },
                set: { settingsVM.expiryWarningDays = $0 }
            )) {
                ForEach(SettingsViewModel.availableExpiryDays, id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            .accessibilityLabel("Expiry warning threshold")

            Picker("Low Stock Warning", selection: Binding(
                get: { settingsVM.lowStockDays },
                set: { settingsVM.lowStockDays = $0 }
            )) {
                ForEach(SettingsViewModel.availableLowStockDays, id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            .accessibilityLabel("Low stock warning threshold")
        } header: {
            Text("Alert Thresholds")
        } footer: {
            Text("Medications will show an 'Expiring Soon' alert within the expiry window. Low stock alerts appear when estimated supply drops below the threshold based on your dosing schedule.")
        }
    }

    // MARK: - Demo Section

    private var demoSection: some View {
        Section {
            Button {
                Task {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    await settingsVM.loadDemoData(
                        inventoryVM: inventoryVM,
                        scheduleVM: scheduleVM
                    )
                }
            } label: {
                HStack {
                    Label("Load Demo Data", systemImage: "tray.and.arrow.down.fill")

                    Spacer()

                    if settingsVM.isLoadingDemo {
                        ProgressView()
                    }
                }
            }
            .disabled(settingsVM.isLoadingDemo)
            .accessibilityLabel("Load demo data")
            .accessibilityHint("Loads sample medications to explore the app")

            Button(role: .destructive) {
                settingsVM.showClearConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash.fill")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Clear all data")
            .accessibilityHint("Permanently removes all medications and data")
        } header: {
            Text("Demo")
        } footer: {
            Text("Load sample medications to explore all features, or clear everything to start fresh.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            Button {
                settingsVM.showAboutSheet = true
            } label: {
                HStack {
                    Label("About MedShelf", systemImage: "info.circle")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel("About MedShelf")

            Button {
                settingsVM.showPrivacySheet = true
            } label: {
                HStack {
                    Label("Privacy", systemImage: "hand.raised.square.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel("Privacy notice")

            Button {
                settingsVM.showSafetySheet = true
            } label: {
                HStack {
                    Label("Safety Disclaimer", systemImage: "exclamationmark.shield.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel("Safety disclaimer")
        } header: {
            Text("About")
        }
    }

    // MARK: - Safety Disclaimer (inline)

    private var safetySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title3)
                        .foregroundStyle(Color(.systemOrange))

                    Text("Important")
                        .font(.headline)
                        .foregroundStyle(Color(.systemOrange))
                }

                Text("This app is a personal organization tool. It does not provide medical advice, diagnosis, or treatment recommendations. Always consult a qualified healthcare professional for medication decisions.")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color(.systemOrange).opacity(0.08))
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Section {
            VStack(spacing: 4) {
                Text("MedShelf v1.0")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Made with care for the Swift Student Challenge 2026")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Privacy Sheet

    private var privacySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised.square.fill")
                            .font(.title)
                            .foregroundStyle(.accentColor)

                        Text("Privacy Notice")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Text(SettingsViewModel.privacyNotice)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settingsVM.showPrivacySheet = false
                    }
                }
            }
        }
    }

    // MARK: - Safety Sheet

    private var safetySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title)
                            .foregroundStyle(Color(.systemOrange))

                        Text("Safety Disclaimer")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Text(SettingsViewModel.safetyDisclaimer)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .navigationTitle("Safety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settingsVM.showSafetySheet = false
                    }
                }
            }
        }
    }

    // MARK: - About Sheet

    private var aboutSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon area
                    VStack(spacing: 12) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.accentColor)

                        Text("MedShelf")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)

                        Text("MedShelf helps families track their home medication inventory -- surfacing expired items, low-stock warnings, and upcoming doses -- so nothing goes to waste and no one misses a dose.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)

                        featureRow(icon: "exclamationmark.triangle.fill", color: .red, text: "Expiration date tracking and alerts")
                        featureRow(icon: "eye.fill", color: .accentColor, text: "Full inventory visibility at a glance")
                        featureRow(icon: "bell.badge.fill", color: .orange, text: "Dose scheduling and reminders")
                        featureRow(icon: "doc.text.viewfinder", color: .blue, text: "On-device OCR for quick data entry")
                        featureRow(icon: "lock.shield.fill", color: .green, text: "100% offline, private by design")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Frameworks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Built With")
                            .font(.headline)

                        Text("SwiftUI, Vision Framework, UserNotifications, PhotosUI")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text("All icons use SF Symbols. No third-party dependencies.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settingsVM.showAboutSheet = false
                    }
                }
            }
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}
