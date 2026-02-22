import SwiftUI

/// A single dose card showing medicine name, dose amount, scheduled time,
/// and Taken/Skip action buttons with haptic feedback.
struct DoseRowView: View {
    let dose: DoseInstance
    let medicine: Medicine?
    var onTaken: (() async -> Void)?
    var onSkip: (() async -> Void)?

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilitySize: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Medicine info row
            HStack(spacing: 10) {
                // Form icon
                Image(systemName: medicine?.form.sfSymbol ?? "pill.fill")
                    .font(.title3)
                    .foregroundStyle(statusForeground)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine?.name ?? "Unknown Medicine")
                        .font(.headline)
                        .foregroundStyle(statusForeground)
                        .strikethrough(dose.isTaken, color: .secondary)

                    if let med = medicine {
                        Text(med.doseText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Scheduled: \(dose.scheduledTime.formattedTime)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if dose.isTaken {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.systemGreen))
                        .symbolEffect(.bounce, value: isAnimating)
                } else if dose.isSkipped {
                    Image(systemName: "forward.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.systemOrange))
                }
            }

            // Action buttons (only for pending doses)
            if dose.isPending {
                if isAccessibilitySize {
                    VStack(spacing: 8) {
                        skipButton
                        takenButton
                    }
                } else {
                    HStack(spacing: 12) {
                        Spacer()
                        skipButton
                        takenButton
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .opacity(dose.isTaken || dose.isSkipped ? 0.5 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: dose.isTaken)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: dose.isSkipped)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                Task {
                    await handleTaken()
                }
            } label: {
                Label("Taken", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                Task {
                    await handleSkip()
                }
            } label: {
                Label("Skip", systemImage: "forward.fill")
            }
            .tint(.orange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityActions {
            if dose.isPending {
                Button("Mark as taken") {
                    Task { await handleTaken() }
                }
                Button("Skip this dose") {
                    Task { await handleSkip() }
                }
            }
        }
    }

    // MARK: - Buttons

    private var skipButton: some View {
        Button {
            Task { await handleSkip() }
        } label: {
            Label("Skip", systemImage: "forward.fill")
                .font(.subheadline)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .accessibilityLabel("Skip this dose")
        .accessibilityHint("Marks this dose as skipped")
    }

    private var takenButton: some View {
        Button {
            Task { await handleTaken() }
        } label: {
            Label("Taken", systemImage: "checkmark")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .accessibilityLabel("Mark as taken")
        .accessibilityHint("Records this dose as taken")
    }

    // MARK: - Actions

    private func handleTaken() async {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isAnimating.toggle()
        await onTaken?()
    }

    private func handleSkip() async {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        await onSkip?()
    }

    // MARK: - Helpers

    private var statusForeground: Color {
        if dose.isTaken || dose.isSkipped {
            return .secondary
        }
        return .primary
    }

    private var accessibilityDescription: String {
        let name = medicine?.name ?? "Unknown medicine"
        let dose = medicine?.doseText ?? ""
        let time = self.dose.scheduledTime.formattedTime
        let status: String
        if self.dose.isTaken {
            status = "Taken"
        } else if self.dose.isSkipped {
            status = "Skipped"
        } else {
            status = "Not taken"
        }
        return "\(name), \(dose), scheduled for \(time), \(status)"
    }
}
