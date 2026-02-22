import SwiftUI
import PhotosUI

/// Photo acquisition view for adding a new medicine via camera, photo library, demo image,
/// or manual entry. This is the entry point for the Add Medication flow.
struct ScanView: View {
    @Bindable var inventoryVM: InventoryViewModel
    @Bindable var scheduleVM: ScheduleViewModel

    @State private var scanVM = ScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch scanVM.currentStep {
                case .capture:
                    captureView
                case .processing:
                    processingView
                case .review:
                    ScanReviewView(
                        scanVM: scanVM,
                        inventoryVM: inventoryVM,
                        scheduleVM: scheduleVM,
                        onDismiss: { dismiss() }
                    )
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Step \(scanVM.currentStep.rawValue) of 3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $scanVM.showCamera) {
                CameraPicker { image in
                    Task {
                        await scanVM.handleCapturedImage(image)
                    }
                }
            }
            .photosPicker(
                isPresented: $scanVM.showPhotoPicker,
                selection: $scanVM.selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: scanVM.selectedPhotoItem) { _, newItem in
                if newItem != nil {
                    Task {
                        await scanVM.handleSelectedPhoto()
                    }
                }
            }
        }
    }

    // MARK: - Capture View (Step 1)

    private var captureView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero illustration
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(.accentColor.opacity(0.6))
                        .accessibilityHidden(true)

                    Text("Scan your medicine box\nor label to get started")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text("Take a photo of the medicine box, select an image from your library, or use a demo image.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 24)

                // Action buttons
                VStack(spacing: 12) {
                    // Camera button (if available)
                    if scanVM.isCameraAvailable {
                        Button {
                            scanVM.showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.body)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(.accentColor)
                        .accessibilityLabel("Take photo of medicine box")
                        .accessibilityHint("Opens the camera to photograph your medicine")
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.slash")
                                .font(.footnote)
                            Text("Camera not available on this device.")
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }

                    // Photo picker button
                    Button {
                        scanVM.showPhotoPicker = true
                    } label: {
                        Label("Choose Photo", systemImage: "photo.on.rectangle.angled")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.accentColor)
                    .accessibilityLabel("Choose photo from library")
                    .accessibilityHint("Opens your photo library to select a medicine image")

                    // Demo image button
                    Button {
                        Task {
                            await scanVM.handleDemoImage()
                        }
                    } label: {
                        Label("Use Demo Image", systemImage: "photo.artframe")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.accentColor)
                    .accessibilityLabel("Use demo image")
                    .accessibilityHint("Uses a sample medicine box image for demonstration")

                    Divider()
                        .padding(.vertical, 4)

                    // Manual entry
                    Button {
                        scanVM.skipToManualEntry()
                    } label: {
                        Label("Enter Manually (Skip Scan)", systemImage: "pencil")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Enter details manually")
                    .accessibilityHint("Skip scanning and type medicine details yourself")
                }
                .padding(.horizontal, 16)

                // Guidance micro-copy
                VStack(spacing: 8) {
                    Divider()
                    Text("For best results, photograph the front of the medicine box in good lighting. Hold the device steady and make sure the text is clearly visible.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Processing View (Step 2)

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Image preview
            if let image = scanVM.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            }

            // Progress indicator
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.accentColor)

                Text(scanVM.processingMessage)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("This may take a few seconds. We're reading the text on your medicine to fill in the details automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing medicine box. Please wait.")
    }
}
