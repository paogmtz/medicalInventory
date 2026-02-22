import ImageIO
import UIKit

// MARK: - Image Pipeline

/// Memory-efficient image processing pipeline using Apple's ImageIO framework.
///
/// Produces three resolution tiers from raw photo data:
///
/// | Tier      | Max Dimension | JPEG Quality | Stored? | Purpose                    |
/// |-----------|---------------|--------------|---------|----------------------------|
/// | OCR       | 1600px        | N/A          | No      | Fed to VNRecognizeTextRequest |
/// | Display   | 512px         | 0.7          | Yes     | Detail view, scan review   |
/// | Thumbnail | 256px         | 0.6          | Yes     | List rows, grid cells      |
///
/// Key design decisions:
/// - Uses `CGImageSourceCreateThumbnailAtIndex` for downsampling, which avoids
///   fully decoding the original image into a bitmap at native resolution.
///   This keeps peak memory low (~10 MB for a 12 MP photo vs ~48 MB with UIImage).
/// - The OCR image is never written to disk; it exists only in memory during
///   the Vision recognition pass.
/// - All methods are static pure functions with no side effects.
/// - Fully offline -- no network calls.
enum ImagePipeline {

    // MARK: - Tier Constants

    /// Maximum pixel dimension for the OCR processing image (in-memory only).
    static let ocrMaxPixelSize: CGFloat = 1600

    /// Maximum pixel dimension for the display-resolution image (persisted).
    static let displayMaxPixelSize: CGFloat = 512

    /// Maximum pixel dimension for the thumbnail image (persisted).
    static let thumbnailMaxPixelSize: CGFloat = 256

    /// JPEG compression quality for the display image.
    static let displayJPEGQuality: CGFloat = 0.7

    /// JPEG compression quality for the thumbnail image.
    static let thumbnailJPEGQuality: CGFloat = 0.6

    // MARK: - Processed Images

    /// The output of the three-tier image processing pipeline.
    struct ProcessedImages: Sendable {
        /// 1600px long side -- fed to Vision for OCR. In-memory only; never persisted.
        let ocrImage: CGImage

        /// 512px long side -- shown in the medicine detail view.
        let displayImage: CGImage

        /// 256px long side -- shown in list rows and grid cells.
        let thumbnail: CGImage

        /// JPEG 0.7 compressed data of `displayImage`, ready to write to disk.
        let displayJPEG: Data

        /// JPEG 0.6 compressed data of `thumbnail`, ready to write to disk.
        let thumbnailJPEG: Data
    }

    // MARK: - Core Downsampling

    /// Downsample image data to a maximum pixel size on the longest side.
    ///
    /// Uses `CGImageSource` (ImageIO) for memory-efficient resizing. The original
    /// image is **not** fully decoded into a bitmap at its native resolution;
    /// instead, ImageIO decodes directly to the target size.
    ///
    /// - Parameters:
    ///   - data: Raw image data (JPEG, PNG, HEIC, etc.).
    ///   - maxPixelSize: The maximum dimension (width or height) of the output image.
    /// - Returns: A downsampled `CGImage`, or `nil` if the data is invalid.
    static func downsample(data: Data, maxPixelSize: CGFloat) -> CGImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            sourceOptions as CFDictionary
        ) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        return CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            downsampleOptions as CFDictionary
        )
    }

    // MARK: - Three-Tier Processing

    /// Process raw photo data into three resolution tiers.
    ///
    /// This is the primary entry point for the scan flow. Call it with the raw
    /// `Data` from `PhotosPicker` or the camera, and receive all three image
    /// tiers plus the pre-compressed JPEG data for persistence.
    ///
    /// Usage:
    /// ```swift
    /// guard let processed = ImagePipeline.process(imageData: rawData) else {
    ///     // Handle invalid image data
    ///     return
    /// }
    /// // Feed processed.ocrImage to OCRManager.scan(image:)
    /// // Save processed.displayJPEG and processed.thumbnailJPEG via ImageStore
    /// ```
    ///
    /// - Parameter imageData: Raw image data from the photo picker or camera.
    /// - Returns: A `ProcessedImages` value containing all three tiers, or `nil`
    ///   if the image data could not be processed.
    static func process(imageData: Data) -> ProcessedImages? {
        // Downsample to each tier
        guard let ocrImg = downsample(data: imageData, maxPixelSize: ocrMaxPixelSize) else {
            return nil
        }
        guard let displayImg = downsample(data: imageData, maxPixelSize: displayMaxPixelSize) else {
            return nil
        }
        guard let thumbImg = downsample(data: imageData, maxPixelSize: thumbnailMaxPixelSize) else {
            return nil
        }

        // Compress display and thumbnail tiers to JPEG for storage
        guard let displayData = UIImage(cgImage: displayImg)
            .jpegData(compressionQuality: displayJPEGQuality) else {
            return nil
        }
        guard let thumbData = UIImage(cgImage: thumbImg)
            .jpegData(compressionQuality: thumbnailJPEGQuality) else {
            return nil
        }

        return ProcessedImages(
            ocrImage: ocrImg,
            displayImage: displayImg,
            thumbnail: thumbImg,
            displayJPEG: displayData,
            thumbnailJPEG: thumbData
        )
    }
}
