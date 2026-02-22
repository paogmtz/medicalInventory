import Foundation

/// A record of a single dose event (taken or skipped).
struct DoseLog: Identifiable, Codable, Hashable {
    let id: UUID
    let scheduleId: UUID
    let medicineId: UUID
    let scheduledTime: Date             // When the dose was supposed to happen
    var status: DoseStatus
    var actionTime: Date?               // When the user actually tapped Taken/Skip

    init(
        id: UUID = UUID(),
        scheduleId: UUID,
        medicineId: UUID,
        scheduledTime: Date,
        status: DoseStatus,
        actionTime: Date? = nil
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.medicineId = medicineId
        self.scheduledTime = scheduledTime
        self.status = status
        self.actionTime = actionTime
    }
}
