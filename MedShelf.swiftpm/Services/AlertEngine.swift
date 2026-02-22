import Foundation

/// Stateless utility for computing expiry and stock status alerts.
/// ViewModels call these pure functions and store the results for display.
enum AlertEngine {

    /// Determine expiry status for a medicine.
    /// - Parameters:
    ///   - expirationDate: The medicine's expiration date (nil = unknown).
    ///   - warningDays: Number of days before expiry to flag as "expiring soon".
    ///   - referenceDate: The date to compare against (defaults to now).
    static func expiryStatus(
        expirationDate: Date?,
        warningDays: Int = 30,
        referenceDate: Date = Date()
    ) -> ExpiryStatus {
        guard let expDate = expirationDate else {
            return .unknown
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfExpiry = calendar.startOfDay(for: expDate)

        guard let daysUntil = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry).day else {
            return .unknown
        }

        if daysUntil < 0 {
            return .expired
        } else if daysUntil <= warningDays {
            return .expiringSoon(daysLeft: daysUntil)
        } else {
            return .ok
        }
    }

    /// Estimate daily consumption from a schedule.
    /// Formula: dosePerIntake * dosesPerDay
    static func dailyConsumption(schedule: Schedule) -> Double {
        schedule.dosePerIntake * schedule.frequency.dosesPerDay
    }

    /// Determine stock status for a medicine.
    /// - Parameters:
    ///   - quantityRemaining: Current stock level.
    ///   - schedule: Active schedule (nil = no schedule, status is .unknown).
    ///   - lowStockDays: Threshold for "low" alert.
    static func stockStatus(
        quantityRemaining: Double,
        schedule: Schedule?,
        lowStockDays: Int = 7
    ) -> StockStatus {
        if quantityRemaining <= 0 {
            return .outOfStock
        }

        guard let schedule = schedule else {
            return .unknown
        }

        let daily = dailyConsumption(schedule: schedule)
        guard daily > 0 else {
            return .adequate
        }

        let daysRemaining = Int(quantityRemaining / daily)

        if daysRemaining <= 0 {
            return .outOfStock
        } else if daysRemaining <= lowStockDays {
            return .low(daysRemaining: daysRemaining)
        } else {
            return .adequate
        }
    }
}
