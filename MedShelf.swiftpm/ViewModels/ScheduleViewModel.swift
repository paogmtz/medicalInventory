import SwiftUI
import Observation

/// Manages dose schedules, generates daily dose instances, and records taken/skip actions.
@Observable
final class ScheduleViewModel {

    // MARK: - State

    var schedules: [Schedule] = []
    var doseLogs: [DoseLog] = []
    var todaysDoses: [DoseInstance] = []
    var isLoading: Bool = false

    // MARK: - Computed Properties

    var takenTodayCount: Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return doseLogs.filter { log in
            log.status == .taken &&
            log.actionTime != nil &&
            calendar.isDate(log.actionTime!, inSameDayAs: startOfDay)
        }.count
    }

    var pendingDoses: [DoseInstance] {
        todaysDoses.filter { $0.isPending }
    }

    var completedDoses: [DoseInstance] {
        todaysDoses.filter { !$0.isPending }
    }

    var upcomingPendingDoses: [DoseInstance] {
        pendingDoses.filter { !$0.isPast }.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    var overdueDoses: [DoseInstance] {
        pendingDoses.filter { $0.isPast }.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// Group today's doses by time-of-day period
    var dosesByPeriod: [(period: String, doses: [DoseInstance])] {
        let grouped = Dictionary(grouping: todaysDoses) { dose in
            dose.scheduledTime.timeOfDayPeriod
        }

        let orderedPeriods = ["Morning", "Afternoon", "Evening", "Night"]
        return orderedPeriods.compactMap { period in
            guard let doses = grouped[period], !doses.isEmpty else { return nil }
            return (period: period, doses: doses.sorted { $0.scheduledTime < $1.scheduledTime })
        }
    }

    var hasDosesToday: Bool {
        !todaysDoses.isEmpty
    }

    // MARK: - Data Operations

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let loadedSchedules: [Schedule] = await JSONStore.shared.loadOrDefault(
            [Schedule].self, from: StoreFile.schedules, default: []
        )
        let loadedLogs: [DoseLog] = await JSONStore.shared.loadOrDefault(
            [DoseLog].self, from: StoreFile.doseLogs, default: []
        )

        await MainActor.run {
            self.schedules = loadedSchedules
            self.doseLogs = loadedLogs
            self.regenerateTodaysDoses()
        }
    }

    func regenerateTodaysDoses() {
        todaysDoses = ScheduleEngine.todaysDoses(
            schedules: schedules,
            logs: doseLogs
        )
    }

    // MARK: - Schedule CRUD

    func schedule(for medicineId: UUID) -> Schedule? {
        schedules.first { $0.medicineId == medicineId }
    }

    func doseLogs(for medicineId: UUID, limit: Int = 10) -> [DoseLog] {
        doseLogs
            .filter { $0.medicineId == medicineId }
            .sorted { ($0.actionTime ?? $0.scheduledTime) > ($1.actionTime ?? $1.scheduledTime) }
            .prefix(limit)
            .map { $0 }
    }

    func saveSchedule(_ schedule: Schedule) async {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }

        await persistSchedules()
        regenerateTodaysDoses()

        // Reschedule notifications
        await rescheduleNotifications()
    }

    func deleteSchedule(for medicineId: UUID) async {
        schedules.removeAll { $0.medicineId == medicineId }
        await persistSchedules()
        regenerateTodaysDoses()
        await NotificationManager.shared.cancelNotifications(for: medicineId)
    }

    func deleteAllSchedules(for medicineId: UUID) async {
        schedules.removeAll { $0.medicineId == medicineId }
        doseLogs.removeAll { $0.medicineId == medicineId }
        await persistSchedules()
        await persistLogs()
        regenerateTodaysDoses()
        await NotificationManager.shared.cancelNotifications(for: medicineId)
    }

    // MARK: - Dose Recording

    func recordDose(
        instance: DoseInstance,
        status: DoseStatus,
        inventoryVM: InventoryViewModel
    ) async {
        guard let schedule = schedules.first(where: { $0.id == instance.scheduleId }) else { return }
        guard let medicine = inventoryVM.medicine(for: instance.medicineId) else { return }

        let result = ScheduleEngine.recordDose(
            instance: instance,
            status: status,
            schedule: schedule,
            currentQuantity: medicine.quantityRemaining
        )

        // Save the dose log
        doseLogs.append(result.log)
        await persistLogs()

        // Update medicine quantity if taken
        if status == .taken {
            await inventoryVM.updateQuantity(for: medicine, newQuantity: result.newQuantity)
        }

        // Regenerate today's doses to reflect the recorded action
        regenerateTodaysDoses()

        // Reschedule notifications
        await rescheduleNotifications()
    }

    // MARK: - Notification Scheduling

    func rescheduleNotifications() async {
        let authorized = await NotificationManager.shared.isAuthorized()
        guard authorized else { return }

        let upcomingInstances = ScheduleEngine.upcomingDoses(
            schedules: schedules.filter { $0.notificationsEnabled },
            logs: doseLogs
        )

        // Build medicine name lookup
        // We don't have direct access to medicines here, so use schedule info
        var nameLookup: [UUID: String] = [:]
        // This will be populated when called from the appropriate context

        await NotificationManager.shared.scheduleNotifications(
            for: upcomingInstances,
            medicines: nameLookup
        )
    }

    func rescheduleNotifications(medicines: [Medicine]) async {
        let authorized = await NotificationManager.shared.isAuthorized()
        guard authorized else { return }

        let upcomingInstances = ScheduleEngine.upcomingDoses(
            schedules: schedules.filter { $0.notificationsEnabled },
            logs: doseLogs
        )

        var nameLookup: [UUID: String] = [:]
        for medicine in medicines {
            nameLookup[medicine.id] = medicine.name
        }

        await NotificationManager.shared.scheduleNotifications(
            for: upcomingInstances,
            medicines: nameLookup
        )
    }

    func requestNotificationPermission() async -> Bool {
        await NotificationManager.shared.requestPermission()
    }

    // MARK: - Persistence

    private func persistSchedules() async {
        do {
            try await JSONStore.shared.save(schedules, to: StoreFile.schedules)
        } catch {
            // Handle silently; data will be reloaded next launch
        }
    }

    private func persistLogs() async {
        do {
            try await JSONStore.shared.save(doseLogs, to: StoreFile.doseLogs)
        } catch {
            // Handle silently
        }
    }
}
