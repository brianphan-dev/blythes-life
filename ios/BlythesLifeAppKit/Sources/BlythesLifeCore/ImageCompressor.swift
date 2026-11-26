import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Cross-platform ImageIO downscaler and JPEG compressor for caregiver paper-scan uploads.
/// Works identically on iOS and macOS with zero UIKit or AppKit dependency.
public enum ImageCompressor: Sendable {
    /// Bytes threshold below which an already properly sized upright JPEG is returned unchanged.
    private static let passthroughSmallJPEGByteLimit = 512 * 1024

    /// Downscales an image to at most `maxDimension` pixels on its longest edge (applying EXIF orientation)
    /// and encodes it as JPEG at `quality`. Falls back cleanly to original bytes for PDFs, non-image payloads,
    /// or already small upright JPEGs.
    public static func compressForScanUpload(
        _ rawData: Data,
        maxDimension: Int = 2200,
        quality: Double = 0.82
    ) -> (data: Data, contentType: String) {
        guard !rawData.isEmpty else {
            return (rawData, "image/jpeg")
        }

        if isPDFData(rawData) {
            return (rawData, "application/pdf")
        }

        guard let source = CGImageSourceCreateWithData(rawData as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else {
            return (rawData, inferContentType(for: rawData))
        }

        let sourceTypeIdentifier = CGImageSourceGetType(source) as String?
        if sourceTypeIdentifier == UTType.pdf.identifier {
            return (rawData, "application/pdf")
        }

        let clampedMax = max(1, maxDimension)
        let clampedQuality = min(1.0, max(0.1, quality))

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let pixelHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let longestEdge = max(pixelWidth, pixelHeight)

        let isAlreadySmallUprightJPEG =
            sourceTypeIdentifier == UTType.jpeg.identifier
            && longestEdge > 0
            && longestEdge <= clampedMax
            && orientation == 1
            && rawData.count <= passthroughSmallJPEGByteLimit

        if isAlreadySmallUprightJPEG {
            return (rawData, "image/jpeg")
        }

        let targetMaxPixelSize = longestEdge > 0 ? min(clampedMax, longestEdge) : clampedMax
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: targetMaxPixelSize
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return (rawData, inferContentType(for: rawData))
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return (rawData, inferContentType(for: rawData))
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: clampedQuality
        ]
        CGImageDestinationAddImage(destination, thumbnail, destinationOptions as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return (rawData, inferContentType(for: rawData))
        }

        let compressed = mutableData as Data
        guard !compressed.isEmpty else {
            return (rawData, inferContentType(for: rawData))
        }

        // If the original was already an upright within-bounds JPEG and recompression didn't shrink it, keep original.
        if sourceTypeIdentifier == UTType.jpeg.identifier,
           longestEdge > 0,
           longestEdge <= clampedMax,
           orientation == 1,
           compressed.count >= rawData.count
        {
            return (rawData, "image/jpeg")
        }

        return (compressed, "image/jpeg")
    }

    // MARK: - Magic Byte Helpers

    private static func isPDFData(_ data: Data) -> Bool {
        guard data.count >= 5 else { return false }
        let prefix = Array(data.prefix(5))
        return prefix == [0x25, 0x50, 0x44, 0x46, 0x2D] // "%PDF-"
    }

    private static func inferContentType(for data: Data) -> String {
        if isPDFData(data) {
            return "application/pdf"
        }
        guard data.count >= 12 else {
            return "image/jpeg"
        }
        let header = Array(data.prefix(12))
        if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "image/jpeg"
        }
        if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "image/png"
        }
        // RIFF....WEBP
        if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46
            && header[8] == 0x57 && header[9] == 0x45 && header[10] == 0x42 && header[11] == 0x50
        {
            return "image/webp"
        }
        // ISO BMFF ftyp brand for HEIC/HEIF
        if header[4] == 0x66 && header[5] == 0x74 && header[6] == 0x79 && header[7] == 0x70 {
            let brand = String(bytes: header[8 ... 11], encoding: .ascii)?.lowercased() ?? ""
            if brand == "heic" || brand == "heix" || brand == "mif1" || brand == "msf1" {
                return "image/heic"
            }
        }
        return "image/jpeg"
    }
}
