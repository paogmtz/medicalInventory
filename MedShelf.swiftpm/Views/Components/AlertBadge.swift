import SwiftUI

/// Colored status badge displaying icon and label for a medicine's alert status.
/// Supports Expired (red), Expiring Soon (orange), Low Stock (blue), and OK (green).
struct AlertBadge: View {
    let status: MedicineStatus
    var showLabel: Bool = true
    var style: BadgeStyle = .compact

    enum BadgeStyle {
        case compact    // Small pill badge for cards
        case expanded   // Larger badge with more detail
        case chip       // Tappable chip for dashboard
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(style == .compact ? .caption2 : .caption)
                .fontWeight(.semibold)

            if showLabel {
                Text(status.rawValue)
                    .font(style == .compact ? .caption : .caption)
                    .fontWeight(.semibold)
            }
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, style == .compact ? 8 : 10)
        .padding(.vertical, style == .compact ? 4 : 6)
        .background(
            status.color.opacity(0.12),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.rawValue) status")
    }
}

/// Tappable alert chip used in the Today Dashboard.
/// Displays status icon, label, and count of affected medicines.
struct AlertChip: View {
    let status: MedicineStatus
    let count: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(status.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        status.color.opacity(0.2),
                        in: Capsule()
                    )
            }
            .foregroundStyle(status.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                status.color.opacity(0.12),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(status.rawValue) medications")
        .accessibilityHint("Shows list of \(status.rawValue.lowercased()) medications")
        .accessibilityValue("\(count) medication\(count == 1 ? "" : "s")")
    }
}

/// Expanded status card for Medication Detail view with explanation text.
struct StatusCard: View {
    let status: MedicineStatus
    let medicine: Medicine
    let settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .font(.headline)
                Text(status.rawValue)
                    .font(.headline)
            }
            .foregroundStyle(status.color)

            Text(explanationText)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(status.color.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.rawValue): \(explanationText)")
    }

    private var explanationText: String {
        switch status {
        case .expired:
            let dateStr = medicine.expirationDate?.formattedMedium ?? "an unknown date"
            return "This medication expired on \(dateStr). Expired medications may lose effectiveness or, in rare cases, become harmful. The FDA recommends safe disposal of expired medications."

        case .expiringSoon:
            let dateStr = medicine.expirationDate?.formattedMedium ?? "soon"
            let days = medicine.expirationDate?.daysFromNow ?? 0
            return "This medication expires on \(dateStr). That's \(days) day\(days == 1 ? "" : "s") from now. You set a warning for \(settings.expiryWarningDays) days before expiration."

        case .lowStock:
            let qty = medicine.quantityRemaining.formattedQuantity
            return "You have \(qty) \(medicine.quantityUnit.displayName) remaining. Consider refilling this medication to avoid running out."

        case .ok:
            let dateStr = medicine.expirationDate?.formattedMedium ?? "no set date"
            let days = medicine.expirationDate?.daysFromNow ?? 0
            let qty = medicine.quantityRemaining.formattedQuantity
            return "This medication is in good standing. Expires on \(dateStr) (\(days) days from now) and you have \(qty) \(medicine.quantityUnit.displayName) remaining."
        }
    }
}

#Preview("Alert Badges") {
    VStack(spacing: 16) {
        ForEach(MedicineStatus.allCases, id: \.self) { status in
            AlertBadge(status: status)
        }

        Divider()

        AlertChip(status: .expired, count: 2) {}
        AlertChip(status: .expiringSoon, count: 3) {}
        AlertChip(status: .lowStock, count: 1) {}
    }
    .padding()
}
