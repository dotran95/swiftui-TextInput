//
//  UIImage+Crop.swift
//  app
//

import UIKit

extension UIImage {
    /// Redraws the image so its pixel buffer matches `.up` orientation, which makes
    /// crop-rect math in point-space unambiguous regardless of how the source photo
    /// was captured (e.g. rotated camera shots from PHPicker).
    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Crops to `rect`, expressed in the image's own point-space (its `size`, not pixels).
    func cropped(to rect: CGRect) -> UIImage? {
        let normalized = normalizedImage()
        guard let cgImage = normalized.cgImage else { return nil }

        let pixelRect = CGRect(
            x: rect.origin.x * normalized.scale,
            y: rect.origin.y * normalized.scale,
            width: rect.width * normalized.scale,
            height: rect.height * normalized.scale
        ).integral

        let imagePixelBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let clampedRect = pixelRect.intersection(imagePixelBounds)
        guard !clampedRect.isEmpty, let croppedCGImage = cgImage.cropping(to: clampedRect) else { return nil }

        return UIImage(cgImage: croppedCGImage, scale: normalized.scale, orientation: .up)
    }
}
