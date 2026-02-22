import SwiftUI

/// A single medicine card for the grid layout showing thumbnail, name, dose,
/// quantity, and status badge.
struct MedicineRowView: View {
    let medicine: Medicine
    let status: MedicineStatus
    @Bindable var inventoryVM: InventoryViewModel

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Photo or placeholder
            imageSection
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Medicine name
            Text(medicine.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Form icon + dose
            HStack(spacing: 4) {
                Image(systemName: medicine.form.sfSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(medicine.doseText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Quantity
            Text("Qty: \(medicine.quantityRemaining.formattedQuantity) \(medicine.quantityUnit.abbreviation)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Status badge
            AlertBadge(status: status, style: .compact)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .task {
            await loadThumbnail()
        }
    }

    // MARK: - Image Section

    @ViewBuilder
    private var imageSection: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityLabel("Photo of \(medicine.name)")
        } else {
            // Placeholder with form icon
            ZStack {
                Color.accentColor.opacity(0.1)

                Image(systemName: medicine.form.sfSymbol)
                    .font(.system(size: 32))
                    .foregroundStyle(.accentColor.opacity(0.5))
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Image Loading

    private func loadThumbnail() async {
        if let img = await inventoryVM.loadThumbnail(for: medicine) {
            await MainActor.run {
                self.thumbnail = img
            }
        }
    }
}

/// A list-style row for medicines (alternative to grid card).
struct MedicineListRowView: View {
    let medicine: Medicine
    let status: MedicineStatus

    var body: some View {
        HStack(spacing: 12) {
            // Form icon
            Image(systemName: medicine.form.sfSymbol)
                .font(.title2)
                .foregroundStyle(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(medicine.name)
                    .font(.headline)

                Text(medicine.doseText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("Qty: \(medicine.quantityRemaining.formattedQuantity)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let expDate = medicine.expirationDate {
                        Text("Exp: \(expDate.formattedShort)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Status badge
            AlertBadge(status: status, showLabel: false, style: .compact)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
