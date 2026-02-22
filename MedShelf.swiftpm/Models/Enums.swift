import Foundation

// MARK: - MedicineForm

/// Pharmaceutical form of a medicine.
enum MedicineForm: String, Codable, CaseIterable, Hashable {
    case tablet
    case capsule
    case syrup
    case cream
    case drops
    case injection
    case other

    var displayName: String {
        switch self {
        case .tablet:    return "Tablet"
        case .capsule:   return "Capsule"
        case .syrup:     return "Syrup"
        case .cream:     return "Cream"
        case .drops:     return "Drops"
        case .injection: return "Injection"
        case .other:     return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .tablet:    return "pill.fill"
        case .capsule:   return "capsule.fill"
        case .syrup:     return "flask.fill"
        case .cream:     return "bandage.fill"
        case .drops:     return "drop.fill"
        case .injection: return "syringe.fill"
        case .other:     return "cross.vial.fill"
        }
    }
}

// MARK: - QuantityUnit

/// Unit of measurement for remaining quantity.
enum QuantityUnit: String, Codable, CaseIterable, Hashable {
    case pills
    case ml
    case g
    case units

    var displayName: String {
        switch self {
        case .pills: return "pills"
        case .ml:    return "mL"
        case .g:     return "g"
        case .units: return "units"
        }
    }

    var abbreviation: String {
        displayName
    }
}

// MARK: - ScheduleFrequency

/// How often a medicine is taken.
enum ScheduleFrequency: Codable, Hashable {
    case everyXHours(Int)
    case timesOfDay([String])   // Each string is "HH:mm" in 24-hour format

    /// Human-readable description of the frequency.
    var displayText: String {
        switch self {
        case .everyXHours(let hours):
            return "Every \(hours) hour\(hours == 1 ? "" : "s")"
        case .timesOfDay(let times):
            let formatted = times.sorted().joined(separator: ", ")
            return "\(times.count)x daily (\(formatted))"
        }
    }

    /// Number of doses per day for stock estimation.
    var dosesPerDay: Double {
        switch self {
        case .everyXHours(let hours):
            return 24.0 / Double(max(hours, 1))
        case .timesOfDay(let times):
            return Double(times.count)
        }
    }
}

// MARK: - DoseStatus

/// Whether a scheduled dose was taken or skipped.
enum DoseStatus: String, Codable, Hashable {
    case taken
    case skipped
}

// MARK: - ExpiryStatus

/// Computed expiration status for display. Not persisted.
enum ExpiryStatus: Hashable {
    case expired
    case expiringSoon(daysLeft: Int)
    case ok
    case unknown   // No expiration date set

    var displayText: String {
        switch self {
        case .expired:
            return "Expired"
        case .expiringSoon(let days):
            return "Expires in \(days) day\(days == 1 ? "" : "s")"
        case .ok:
            return "OK"
        case .unknown:
            return "No expiry date"
        }
    }

    var color: String {
        switch self {
        case .expired:        return "red"
        case .expiringSoon:   return "orange"
        case .ok:             return "green"
        case .unknown:        return "gray"
        }
    }
}

// MARK: - StockStatus

/// Computed stock level status for display. Not persisted.
enum StockStatus: Hashable {
    case outOfStock
    case low(daysRemaining: Int)
    case adequate
    case unknown    // No schedule to estimate against

    var displayText: String {
        switch self {
        case .outOfStock:
            return "Out of stock"
        case .low(let days):
            return "\(days) day\(days == 1 ? "" : "s") of supply left"
        case .adequate:
            return "Well stocked"
        case .unknown:
            return "No schedule"
        }
    }
}
