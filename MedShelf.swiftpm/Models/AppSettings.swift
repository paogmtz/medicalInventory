import Foundation

/// Global application settings. Persisted as a single JSON object.
struct AppSettings: Codable, Hashable {
    var expiryWarningDays: Int          // Days before expiry to show warning
    var lowStockDays: Int               // Days of supply remaining to trigger low-stock alert
    var isDemoMode: Bool                // Whether demo data is currently loaded

    init(
        expiryWarningDays: Int = 30,
        lowStockDays: Int = 7,
        isDemoMode: Bool = false
    ) {
        self.expiryWarningDays = expiryWarningDays
        self.lowStockDays = lowStockDays
        self.isDemoMode = isDemoMode
    }

    static let `default` = AppSettings()
}
