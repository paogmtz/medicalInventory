import SwiftUI

/// Create or edit a dose schedule for a medicine.
/// Allows setting frequency type, times of day, dose per intake, and notification toggle.
struct ScheduleEditView: View {
    let medicine: Medicine
    @Bindable var scheduleVM: ScheduleViewModel
    var existingSchedule: Schedule?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var frequencyType: FrequencyType = .timesOfDay
    @State private var intervalHours: Int = 8
    @State private var times: [Date] = [
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    ]
    @State private var dosePerIntake: String = "1"
    @State private var notificationsEnabled: Bool = true
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var showPermissionAlert: Bool = false

    enum FrequencyType: String, CaseIterable, Identifiable {
        case timesOfDay = "Specific Times"
        case everyXHours = "Every X Hours"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Medication Info
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: medicine.form.sfSymbol)
                            .font(.title3)
                            .foregroundStyle(.accentColor)
                            .frame(width: 32)

                        VStack(alignment: .leading) {
                            Text(medicine.name)
                                .font(.headline)
                            Text(medicine.doseText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Frequency
                Section("Frequency") {
                    Picker("Type", selection: $frequencyType) {
                        ForEach(FrequencyType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if frequencyType == .timesOfDay {
                        timesOfDaySection
                    } else {
                        intervalSection
                    }
                }

                // Dose per intake
                Section("Dose per Intake") {
                    HStack {
                        TextField("Amount", text: $dosePerIntake)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)

                        Text(medicine.quantityUnit.displayName)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("How much you take each time (e.g., 1 tablet, 5 mL).")
                }

                // Date range
                Section("Schedule Period") {
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )

                    Toggle("Set End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                    }
                }

                // Notifications
                Section("Reminders") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell.badge.fill")
                    }
                } footer: {
                    Text("When enabled, you'll receive a reminder before each scheduled dose.")
                }
            }
            .navigationTitle(existingSchedule != nil ? "Edit Schedule" : "Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveSchedule() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
                Button("Continue Without Notifications") {
                    notificationsEnabled = false
                    Task { await saveSchedule() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Notification permission was not granted. The schedule will be saved without push notifications. You can still track doses in the Today tab.")
            }
            .onAppear {
                loadExistingSchedule()
            }
        }
    }

    // MARK: - Times of Day Section

    private var timesOfDaySection: some View {
        Group {
            ForEach(times.indices, id: \.self) { index in
                HStack {
                    DatePicker(
                        "Time \(index + 1)",
                        selection: $times[index],
                        displayedComponents: .hourAndMinute
                    )

                    if times.count > 1 {
                        Button(role: .destructive) {
                            times.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove time \(index + 1)")
                    }
                }
            }

            Button {
                let newTime = Calendar.current.date(
                    bySettingHour: 12, minute: 0, second: 0, of: Date()
                ) ?? Date()
                times.append(newTime)
            } label: {
                Label("Add Time", systemImage: "plus.circle")
            }
            .accessibilityLabel("Add another dose time")
        }
    }

    // MARK: - Interval Section

    private var intervalSection: some View {
        Group {
            Picker("Every", selection: $intervalHours) {
                Text("4 hours").tag(4)
                Text("6 hours").tag(6)
                Text("8 hours").tag(8)
                Text("12 hours").tag(12)
                Text("24 hours").tag(24)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        guard let dose = Double(dosePerIntake), dose > 0 else { return false }
        if frequencyType == .timesOfDay && times.isEmpty { return false }
        return true
    }

    // MARK: - Load Existing

    private func loadExistingSchedule() {
        guard let schedule = existingSchedule else { return }

        dosePerIntake = schedule.dosePerIntake.formattedQuantity
        notificationsEnabled = schedule.notificationsEnabled
        startDate = schedule.startDate
        hasEndDate = schedule.endDate != nil
        endDate = schedule.endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        switch schedule.frequency {
        case .timesOfDay(let timeStrings):
            frequencyType = .timesOfDay
            let calendar = Calendar.current
            times = timeStrings.compactMap { timeStr in
                let parts = timeStr.split(separator: ":")
                guard parts.count == 2,
                      let hour = Int(parts[0]),
                      let minute = Int(parts[1]) else { return nil }
                return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
            }
            if times.isEmpty {
                times = [calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()]
            }

        case .everyXHours(let hours):
            frequencyType = .everyXHours
            intervalHours = hours
        }
    }

    // MARK: - Save

    private func saveSchedule() async {
        // Check notification permission if enabled
        if notificationsEnabled {
            let authorized = await scheduleVM.requestNotificationPermission()
            if !authorized {
                showPermissionAlert = true
                return
            }
        }

        let frequency: ScheduleFrequency
        switch frequencyType {
        case .timesOfDay:
            let calendar = Calendar.current
            let timeStrings = times.map { date -> String in
                let hour = calendar.component(.hour, from: date)
                let minute = calendar.component(.minute, from: date)
                return String(format: "%02d:%02d", hour, minute)
            }
            frequency = .timesOfDay(timeStrings)

        case .everyXHours:
            frequency = .everyXHours(intervalHours)
        }

        let schedule = Schedule(
            id: existingSchedule?.id ?? UUID(),
            medicineId: medicine.id,
            dosePerIntake: Double(dosePerIntake) ?? 1.0,
            frequency: frequency,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            notificationsEnabled: notificationsEnabled
        )

        await scheduleVM.saveSchedule(schedule)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
