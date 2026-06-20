//
//  ImageResizer.swift
//  MealTracker
//
//  Resizing and JPEG export for iOS.
//

import UIKit
import CoreImage
import CryptoKit

struct ImageResizer {

    struct ResizeResult {
        let image: UIImage
        let jpegData: Data
        let width: Int
        let height: Int
        let byteSize: Int
    }

    // Resize to fit within maxLongEdge while preserving aspect ratio.
    // IMPORTANT: Draw the original UIImage so its imageOrientation is applied,
    // producing pixels that are normalized to .up (portrait stays portrait).
    static func resizeToLongEdge(_ maxLongEdge: CGFloat,
                                 image: UIImage,
                                 jpegQuality: CGFloat = 0.72) -> ResizeResult? {
        // Compute oriented pixel size (UIImage.size is in points, already oriented)
        let pixelScale = max(1.0, image.scale)
        let orientedPixelSize = CGSize(width: image.size.width * pixelScale,
                                       height: image.size.height * pixelScale)

        // Determine scale factor without upscaling
        let longEdge = max(orientedPixelSize.width, orientedPixelSize.height)
        let scale = min(1.0, maxLongEdge / longEdge)

        let targetSize = CGSize(width: floor(orientedPixelSize.width * scale),
                                height: floor(orientedPixelSize.height * scale))

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        // Work in pixel units so width/height map 1:1 to encoded JPEG pixels
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)

        // Draw the original UIImage (not its cgImage) so UIKit applies orientation.
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        return ResizeResult(image: resized,
                            jpegData: data,
                            width: Int(targetSize.width),
                            height: Int(targetSize.height),
                            byteSize: data.count)
    }

    // Compute SHA-256 of data as hex string
    static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private extension CIImage {
    func toCGImage() -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(self, from: extent)
    }
}
