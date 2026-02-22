import Foundation
import SwiftUI

// MARK: - Date Formatting Helpers

extension Date {
    /// "February 21, 2026"
    var formattedLong: String {
        formatted(.dateTime.month(.wide).day().year())
    }

    /// "Feb 21, 2026"
    var formattedMedium: String {
        formatted(.dateTime.month(.abbreviated).day().year())
    }

    /// "Feb 21"
    var formattedShort: String {
        formatted(.dateTime.month(.abbreviated).day())
    }

    /// "8:00 AM"
    var formattedTime: String {
        formatted(.dateTime.hour().minute())
    }

    /// "Friday, February 21"
    var formattedDayAndDate: String {
        formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// Days from now (positive = future, negative = past)
    var daysFromNow: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: self)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
    }

    /// Time-of-day greeting
    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    /// Returns time-of-day period label
    var timeOfDayPeriod: String {
        let hour = Calendar.current.component(.hour, from: self)
        switch hour {
        case 0..<6:
            return "Night"
        case 6..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<21:
            return "Evening"
        default:
            return "Night"
        }
    }

    /// Start of today
    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// End of today
    static var endOfToday: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
    }
}

// MARK: - String Extensions

extension String {
    /// Trims whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns nil if the string is empty after trimming
    var nilIfEmpty: String? {
        let t = trimmed
        return t.isEmpty ? nil : t
    }
}

// MARK: - Double Extensions

extension Double {
    /// Formats as integer if whole, otherwise one decimal place
    var formattedQuantity: String {
        if self == floor(self) {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }
}

// MARK: - Color Helpers

extension Color {
    static let accentTeal = Color("AccentTeal")
    static let accentTealLight = Color("AccentTealLight")

    /// Fallback teal color if asset catalog color is not available
    static let medShelfTeal = Color(red: 0.165, green: 0.647, blue: 0.627)
    static let medShelfTealLight = Color(red: 0.902, green: 0.961, blue: 0.957)
}

// MARK: - View Extensions

extension View {
    /// Standard card styling
    func cardStyle() -> some View {
        self
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    /// Apply animation only when reduce motion is not enabled
    func animateIfAllowed<V: Equatable>(_ animation: Animation, value: V, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}
