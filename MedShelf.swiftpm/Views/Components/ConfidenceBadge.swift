import SwiftUI

/// Displays an OCR confidence indicator next to auto-filled form fields.
/// Shows a green checkmark for high confidence, orange diamond for low confidence,
/// and nothing for manually entered fields.
struct ConfidenceBadge: View {
    let confidence: FieldConfidence
    var showTooltip: Bool = false
    @State private var isShowingTooltip: Bool = false

    var body: some View {
        if let icon = confidence.icon {
            Button {
                isShowingTooltip.toggle()
            } label: {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(confidence.color)
                    .frame(minWidth: 24, minHeight: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(confidence.accessibilityLabel)
            .accessibilityHint("Tap for more information about this auto-filled value")
            .popover(isPresented: $isShowingTooltip) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundStyle(confidence.color)
                        Text(confidence == .high ? "High Confidence" : "Low Confidence")
                            .font(.headline)
                    }

                    Text(tooltipText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: 280)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var tooltipText: String {
        switch confidence {
        case .high:
            return "This field was automatically filled from the scanned text with high confidence. It is likely correct, but please verify before saving."
        case .low:
            return "This field was automatically filled from the scanned text, but the app is not very confident about this value. Please check it carefully and correct if needed."
        case .manual:
            return ""
        }
    }
}

/// An overall OCR confidence indicator shown at the top of the review screen.
struct OverallConfidenceBadge: View {
    let confidence: Double

    private var level: ConfidenceLevel {
        if confidence >= 0.8 { return .high }
        if confidence >= 0.5 { return .medium }
        return .low
    }

    private enum ConfidenceLevel {
        case high, medium, low

        var icon: String {
            switch self {
            case .high: return "checkmark.seal.fill"
            case .medium: return "exclamationmark.triangle"
            case .low: return "questionmark.diamond"
            }
        }

        var color: Color {
            switch self {
            case .high: return Color(.systemGreen)
            case .medium: return Color(.systemOrange)
            case .low: return Color(.systemRed)
            }
        }

        var label: String {
            switch self {
            case .high: return "High confidence scan"
            case .medium: return "Moderate confidence - please review"
            case .low: return "Low confidence - manual review needed"
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: level.icon)
                .font(.subheadline)
                .foregroundStyle(level.color)

            Text(level.label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(Int(confidence * 100))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(level.color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(level.color.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan confidence: \(Int(confidence * 100)) percent. \(level.label)")
    }
}

#Preview("Confidence Badges") {
    VStack(spacing: 20) {
        HStack {
            Text("Name")
            Spacer()
            ConfidenceBadge(confidence: .high)
        }
        HStack {
            Text("Dose")
            Spacer()
            ConfidenceBadge(confidence: .low)
        }
        HStack {
            Text("Notes")
            Spacer()
            ConfidenceBadge(confidence: .manual)
        }

        Divider()

        OverallConfidenceBadge(confidence: 0.92)
        OverallConfidenceBadge(confidence: 0.65)
        OverallConfidenceBadge(confidence: 0.35)
    }
    .padding()
}
