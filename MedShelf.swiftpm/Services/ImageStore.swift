import UIKit

/// Actor-based image persistence. Manages display images and thumbnails in separate subdirectories.
actor ImageStore {
    static let shared = ImageStore()

    private let fileManager = FileManager.default

    private var imagesDir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var thumbnailsDir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Save display image and thumbnail. Returns (photoFilename, thumbnailFilename).
    func save(
        displayImageData: Data,
        thumbnailData: Data,
        id: UUID
    ) throws -> (photo: String, thumbnail: String) {
        let photoName = "\(id.uuidString).jpg"
        let thumbName = "\(id.uuidString)_thumb.jpg"

        try displayImageData.write(to: imagesDir.appendingPathComponent(photoName), options: .atomic)
        try thumbnailData.write(to: thumbnailsDir.appendingPathComponent(thumbName), options: .atomic)

        return (photoName, thumbName)
    }

    func loadImage(filename: String) -> UIImage? {
        let url = imagesDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(filename: String) -> UIImage? {
        let url = thumbnailsDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteImages(id: UUID) throws {
        let photoURL = imagesDir.appendingPathComponent("\(id.uuidString).jpg")
        let thumbURL = thumbnailsDir.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        if fileManager.fileExists(atPath: photoURL.path) {
            try fileManager.removeItem(at: photoURL)
        }
        if fileManager.fileExists(atPath: thumbURL.path) {
            try fileManager.removeItem(at: thumbURL)
        }
    }

    func totalStorageBytes() -> Int64 {
        var total: Int64 = 0
        for dir in [imagesDir, thumbnailsDir] {
            if let files = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey]
            ) {
                for file in files {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
                }
            }
        }
        return total
    }
}
