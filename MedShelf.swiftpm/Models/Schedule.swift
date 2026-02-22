import Foundation

/// A dosing schedule attached to a medicine.
struct Schedule: Identifiable, Codable, Hashable {
    let id: UUID
    let medicineId: UUID
    var dosePerIntake: Double           // Amount consumed per dose (e.g., 1.0 pill, 5.0 mL)
    var frequency: ScheduleFrequency
    var startDate: Date
    var endDate: Date?                  // nil = indefinite
    var notificationsEnabled: Bool

    init(
        id: UUID = UUID(),
        medicineId: UUID,
        dosePerIntake: Double = 1.0,
        frequency: ScheduleFrequency = .timesOfDay(["08:00"]),
        startDate: Date = Date(),
        endDate: Date? = nil,
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.medicineId = medicineId
        self.dosePerIntake = dosePerIntake
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.notificationsEnabled = notificationsEnabled
    }
}
