import Foundation

/// Stateless utility for generating dose instances from schedules and recording dose actions.
enum ScheduleEngine {

    /// Generate all dose instances for a schedule within a date range.
    /// This is the core function for "Today's Doses" and the weekly calendar.
    static func generateInstances(
        schedule: Schedule,
        from startDate: Date,
        to endDate: Date,
        existingLogs: [DoseLog]
    ) -> [DoseInstance] {
        let calendar = Calendar.current
        var instances: [DoseInstance] = []

        // Clamp to schedule bounds
        let effectiveStart = max(startDate, schedule.startDate)
        let effectiveEnd: Date
        if let schedEnd = schedule.endDate {
            effectiveEnd = min(endDate, schedEnd)
        } else {
            effectiveEnd = endDate
        }

        guard effectiveStart <= effectiveEnd else { return [] }

        switch schedule.frequency {
        case .timesOfDay(let times):
            // Iterate day by day
            var currentDay = calendar.startOfDay(for: effectiveStart)
            while currentDay <= effectiveEnd {
                for timeString in times {
                    if let time = parseTimeString(timeString),
                       let doseTime = calendar.date(
                        bySettingHour: time.hour, minute: time.minute, second: 0, of: currentDay
                       ),
                       doseTime >= effectiveStart && doseTime <= effectiveEnd {

                        let instanceId = "\(schedule.id.uuidString)-\(iso(doseTime))"
                        let matchingLog = existingLogs.first {
                            $0.scheduleId == schedule.id &&
                            calendar.isDate($0.scheduledTime, equalTo: doseTime, toGranularity: .minute)
                        }

                        instances.append(DoseInstance(
                            id: instanceId,
                            scheduleId: schedule.id,
                            medicineId: schedule.medicineId,
                            scheduledTime: doseTime,
                            log: matchingLog
                        ))
                    }
                }
                currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
            }

        case .everyXHours(let interval):
            // Start from the schedule's start time and step forward
            var cursor = schedule.startDate
            while cursor <= effectiveEnd {
                if cursor >= effectiveStart {
                    let instanceId = "\(schedule.id.uuidString)-\(iso(cursor))"
                    let matchingLog = existingLogs.first {
                        $0.scheduleId == schedule.id &&
                        calendar.isDate($0.scheduledTime, equalTo: cursor, toGranularity: .minute)
                    }
                    instances.append(DoseInstance(
                        id: instanceId,
                        scheduleId: schedule.id,
                        medicineId: schedule.medicineId,
                        scheduledTime: cursor,
                        log: matchingLog
                    ))
                }
                cursor = calendar.date(byAdding: .hour, value: interval, to: cursor)!
            }
        }

        return instances.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// Generate today's dose instances for all active schedules.
    static func todaysDoses(
        schedules: [Schedule],
        logs: [DoseLog]
    ) -> [DoseInstance] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return schedules.flatMap { schedule in
            generateInstances(schedule: schedule, from: startOfDay, to: endOfDay, existingLogs: logs)
        }
        .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// Generate a 7-day rolling window of dose instances for notification scheduling.
    static func upcomingDoses(
        schedules: [Schedule],
        logs: [DoseLog],
        days: Int = 7
    ) -> [DoseInstance] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: now)!
        return schedules.flatMap { schedule in
            generateInstances(schedule: schedule, from: now, to: end, existingLogs: logs)
        }
        .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// Record a dose action. Returns the new DoseLog and the updated quantity.
    /// Caller is responsible for persisting both the log and the updated Medicine.
    static func recordDose(
        instance: DoseInstance,
        status: DoseStatus,
        schedule: Schedule,
        currentQuantity: Double
    ) -> (log: DoseLog, newQuantity: Double) {
        let log = DoseLog(
            scheduleId: instance.scheduleId,
            medicineId: instance.medicineId,
            scheduledTime: instance.scheduledTime,
            status: status,
            actionTime: Date()
        )

        var newQuantity = currentQuantity
        if status == .taken {
            newQuantity = max(0, currentQuantity - schedule.dosePerIntake)
        }
        // .skipped does not decrement quantity

        return (log, newQuantity)
    }

    // MARK: - Helpers

    private static func parseTimeString(_ string: String) -> (hour: Int, minute: Int)? {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else {
            return nil
        }
        return (h, m)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func iso(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}
