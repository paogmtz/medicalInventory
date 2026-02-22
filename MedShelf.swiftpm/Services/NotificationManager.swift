import UserNotifications

// MARK: - Notification Manager

/// Actor-based wrapper around `UNUserNotificationCenter` for scheduling
/// medication dose reminders.
///
/// Design:
/// - **Actor isolation** prevents data races when multiple ViewModels
///   schedule or cancel notifications concurrently.
/// - **Rolling window**: iOS limits each app to 64 pending local notifications.
///   This manager caps at 60 (leaving 4 as buffer) and prioritizes the
///   nearest upcoming doses.
/// - **Singleton**: Access via `NotificationManager.shared`.
/// - **Fully offline**: No network calls; all notifications are local.
///
/// Rescheduling triggers (handled by callers):
/// - App enters foreground (`scenePhase == .active`).
/// - Schedule created, edited, or deleted.
/// - Dose recorded (Taken / Skip).
/// - Medicine deleted.
actor NotificationManager {
    static let shared = NotificationManager()

    /// Maximum number of notifications to schedule at once.
    /// iOS allows 64; we reserve 4 as buffer for system/edge-case use.
    private let maxScheduledNotifications = 60

    /// Category identifier used for all dose reminder notifications.
    /// Can be used to register custom actions (Taken / Skip) in the future.
    private let categoryIdentifier = "DOSE_REMINDER"

    // MARK: - Permission

    /// Request notification authorization from the user.
    ///
    /// Call this at a meaningful moment (e.g., when the user creates their
    /// first schedule with notifications enabled), not at app launch.
    ///
    /// - Returns: `true` if the user granted permission, `false` otherwise.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Query the current notification authorization status without prompting.
    ///
    /// - Returns: The current `UNAuthorizationStatus`.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
    }

    /// Convenience check for whether notifications are currently authorized.
    ///
    /// - Returns: `true` if status is `.authorized` or `.provisional`.
    func isAuthorized() async -> Bool {
        let status = await authorizationStatus()
        return status == .authorized || status == .provisional
    }

    // MARK: - Scheduling

    /// Schedule local notifications for a set of dose instances.
    ///
    /// This method implements a **full-replace** strategy:
    /// 1. All existing pending notifications are removed.
    /// 2. The provided instances are filtered to future, pending doses only.
    /// 3. Instances are sorted by time (nearest first) and capped at 60.
    /// 4. A `UNCalendarNotificationTrigger` is created for each.
    ///
    /// Each notification includes:
    /// - Title: "Medication Reminder"
    /// - Body: "Time to take {medicine name}"
    /// - Sound: `.default`
    /// - Category: "DOSE_REMINDER"
    /// - UserInfo: `medicineId` and `scheduleId` for routing taps.
    ///
    /// - Parameters:
    ///   - instances: All dose instances from `ScheduleEngine.upcomingDoses()`.
    ///   - medicines: A dictionary mapping `UUID` -> medicine name for display.
    func scheduleNotifications(
        for instances: [DoseInstance],
        medicines: [UUID: String]
    ) async {
        let center = UNUserNotificationCenter.current()

        // Step 1: Clear all pending notifications
        center.removeAllPendingNotificationRequests()

        // Step 2: Filter to future, pending (not yet taken/skipped) instances
        let now = Date()
        let toSchedule = instances
            .filter { $0.scheduledTime > now && $0.isPending }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .prefix(maxScheduledNotifications)

        // Step 3: Create and register each notification
        for instance in toSchedule {
            let content = UNMutableNotificationContent()
            content.title = "Medication Reminder"
            content.body = "Time to take \(medicines[instance.medicineId] ?? "your medicine")"
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = [
                "medicineId": instance.medicineId.uuidString,
                "scheduleId": instance.scheduleId.uuidString
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: instance.scheduledTime
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: instance.id,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                // Silently skip notifications that fail to schedule.
                // This can happen if the system is under pressure or the
                // notification is too far in the future.
                continue
            }
        }
    }

    // MARK: - Cancellation

    /// Cancel all pending notifications associated with a specific medicine.
    ///
    /// Iterates through all pending requests and removes those whose `userInfo`
    /// contains a matching `medicineId`. This is used when a medicine or its
    /// schedule is deleted.
    ///
    /// - Parameter medicineId: The UUID of the medicine whose notifications
    ///   should be cancelled.
    func cancelNotifications(for medicineId: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let idsToRemove = pending.compactMap { request -> String? in
            guard let storedId = request.content.userInfo["medicineId"] as? String,
                  storedId == medicineId.uuidString else {
                return nil
            }
            return request.identifier
        }

        if !idsToRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    /// Remove all pending notifications managed by this app.
    ///
    /// Used during demo mode reset or full data wipe.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Diagnostics

    /// Return the count of currently pending notification requests.
    ///
    /// Useful for debugging and for displaying notification status in Settings.
    func pendingCount() async -> Int {
        await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .count
    }
}
