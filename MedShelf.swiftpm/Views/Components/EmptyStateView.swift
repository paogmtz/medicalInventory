import SwiftUI

/// Reusable empty state view with SF Symbol illustration, title, subtitle, and optional CTA button.
/// Used throughout the app when lists or sections have no content.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var ctaTitle: String?
    var ctaAction: (() -> Void)?
    var secondaryCtaTitle: String?
    var secondaryCtaIcon: String?
    var secondaryCtaAction: (() -> Void)?
    var iconSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            if let ctaTitle, let ctaAction {
                Button(action: ctaAction) {
                    Label(ctaTitle, systemImage: "plus.circle.fill")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)
                .padding(.top, 8)
                .accessibilityLabel(ctaTitle)
            }

            if let secondaryTitle = secondaryCtaTitle,
               let secondaryAction = secondaryCtaAction {
                Button(action: secondaryAction) {
                    Label(
                        secondaryTitle,
                        systemImage: secondaryCtaIcon ?? "tray.and.arrow.down.fill"
                    )
                    .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.accentColor)
                .accessibilityLabel(secondaryTitle)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Small inline empty state for sections within a larger view.
struct InlineEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var ctaTitle: String?
    var ctaAction: (() -> Void)?
    var iconSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let ctaTitle, let ctaAction {
                Button(action: ctaAction) {
                    Label(ctaTitle, systemImage: "plus.circle")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Empty States") {
    VStack {
        EmptyStateView(
            icon: "pills.circle",
            title: "Your medicine cabinet is empty",
            subtitle: "Add your first medication by scanning the box or entering the details manually.",
            ctaTitle: "Add Your First Medication",
            ctaAction: {},
            secondaryCtaTitle: "Load Demo Data",
            secondaryCtaAction: {}
        )
    }
}
