import Foundation
import UIKit

/// Generates and manages demo data for the SSC judging experience.
enum DemoDataService {

    /// Generate demo medicines with varied states for SSC judging.
    static func makeDemoMedicines() -> [Medicine] {
        let now = Date()
        let calendar = Calendar.current

        return [
            // 1. Healthy stock, not expiring soon
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Amoxicillin",
                doseText: "500 mg",
                form: .capsule,
                quantityRemaining: 21,
                quantityUnit: .pills,
                expirationDate: calendar.date(byAdding: .month, value: 8, to: now),
                notes: "Antibiotic - take with food"
            ),

            // 2. Low stock
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Ibuprofen",
                doseText: "400 mg",
                form: .tablet,
                quantityRemaining: 4,
                quantityUnit: .pills,
                expirationDate: calendar.date(byAdding: .month, value: 14, to: now),
                notes: "Pain relief - do not exceed 3 per day"
            ),

            // 3. Expiring soon (within 30 days)
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Loratadine",
                doseText: "10 mg",
                form: .tablet,
                quantityRemaining: 15,
                quantityUnit: .pills,
                expirationDate: calendar.date(byAdding: .day, value: 18, to: now),
                notes: "Allergy relief - once daily"
            ),

            // 4. Expired
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                name: "Cough Syrup",
                doseText: "15 mg/5 mL",
                form: .syrup,
                quantityRemaining: 60,
                quantityUnit: .ml,
                expirationDate: calendar.date(byAdding: .day, value: -45, to: now),
                notes: "EXPIRED - Dispose properly"
            ),

            // 5. No expiration date, liquid form
            Medicine(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                name: "Eye Drops",
                doseText: "0.5%",
                form: .drops,
                quantityRemaining: 10,
                quantityUnit: .ml,
                expirationDate: nil,
                notes: "Lubricating eye drops - use as needed"
            ),
        ]
    }

    /// Generate demo schedules matching the demo medicines.
    static func makeDemoSchedules() -> [Schedule] {
        return [
            // Amoxicillin: 3x daily
            Schedule(
                medicineId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                dosePerIntake: 1.0,
                frequency: .timesOfDay(["08:00", "14:00", "20:00"]),
                notificationsEnabled: true
            ),

            // Ibuprofen: every 8 hours
            Schedule(
                medicineId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                dosePerIntake: 1.0,
                frequency: .everyXHours(8),
                notificationsEnabled: true
            ),

            // Loratadine: once daily
            Schedule(
                medicineId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                dosePerIntake: 1.0,
                frequency: .timesOfDay(["09:00"]),
                notificationsEnabled: false
            ),
        ]
    }

    /// Generate a few demo dose logs (some taken, some skipped) for today.
    static func makeDemoLogs(schedules: [Schedule]) -> [DoseLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var logs: [DoseLog] = []

        // Amoxicillin 08:00 -- taken
        if let schedule = schedules.first,
           let time = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) {
            logs.append(DoseLog(
                scheduleId: schedule.id,
                medicineId: schedule.medicineId,
                scheduledTime: time,
                status: .taken,
                actionTime: calendar.date(bySettingHour: 8, minute: 5, second: 0, of: today)
            ))
        }

        return logs
    }

    /// Create a simple placeholder image from an SF Symbol for demo mode.
    static func makePlaceholderImage(symbol: String, size: CGFloat = 256) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size * 0.4, weight: .light)
        let image = UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(.systemGray3, renderingMode: .alwaysOriginal)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            let imageSize = image?.size ?? .zero
            let origin = CGPoint(
                x: (size - imageSize.width) / 2,
                y: (size - imageSize.height) / 2
            )
            image?.draw(at: origin)
        }
    }

    /// Load all demo data into persistence. Sets isDemoMode = true in settings.
    static func activate() async throws {
        let store = JSONStore.shared
        let imgStore = ImageStore.shared

        let medicines = makeDemoMedicines()
        let schedules = makeDemoSchedules()
        let logs = makeDemoLogs(schedules: schedules)

        try await store.save(medicines, to: StoreFile.medicines)
        try await store.save(schedules, to: StoreFile.schedules)
        try await store.save(logs, to: StoreFile.doseLogs)

        var settings = AppSettings.default
        settings.isDemoMode = true
        try await store.save(settings, to: StoreFile.settings)

        // Generate placeholder thumbnails for demo medicines
        let symbolMap: [String: String] = [
            "00000000-0000-0000-0000-000000000001": "capsule.fill",
            "00000000-0000-0000-0000-000000000002": "pill.fill",
            "00000000-0000-0000-0000-000000000003": "pill.fill",
            "00000000-0000-0000-0000-000000000004": "flask.fill",
            "00000000-0000-0000-0000-000000000005": "drop.fill",
        ]

        for medicine in medicines {
            if let symbol = symbolMap[medicine.id.uuidString],
               let placeholder = makePlaceholderImage(symbol: symbol, size: 256),
               let thumbData = placeholder.jpegData(compressionQuality: 0.6),
               let displayPlaceholder = makePlaceholderImage(symbol: symbol, size: 512),
               let displayData = displayPlaceholder.jpegData(compressionQuality: 0.7) {
                _ = try await imgStore.save(
                    displayImageData: displayData,
                    thumbnailData: thumbData,
                    id: medicine.id
                )
            }
        }
    }

    /// Erase all user data and demo data. Returns to clean state.
    static func reset() async throws {
        let store = JSONStore.shared

        try await store.delete(filename: StoreFile.medicines)
        try await store.delete(filename: StoreFile.schedules)
        try await store.delete(filename: StoreFile.doseLogs)

        var settings = AppSettings.default
        settings.isDemoMode = false
        try await store.save(settings, to: StoreFile.settings)

        // Image cleanup: delete all files in Images/ and Thumbnails/
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for subdir in ["Images", "Thumbnails"] {
            let dir = docs.appendingPathComponent(subdir)
            if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
}
