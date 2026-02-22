import Foundation

/// A single expected dose at a specific time. Generated from a Schedule, not stored.
struct DoseInstance: Identifiable, Hashable {
    let id: String              // Deterministic: "\(scheduleId)-\(isoTimestamp)"
    let scheduleId: UUID
    let medicineId: UUID
    let scheduledTime: Date
    var log: DoseLog?           // Non-nil if a log entry exists for this instance

    var isPast: Bool {
        scheduledTime < Date()
    }

    var isTaken: Bool {
        log?.status == .taken
    }

    var isSkipped: Bool {
        log?.status == .skipped
    }

    var isPending: Bool {
        log == nil
    }
}
