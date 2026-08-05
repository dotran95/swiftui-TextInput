//
//  ImageCropCalculator.swift
//  app
//

import CoreGraphics

/// Pure geometry helpers for the zoom/pan background preview.
/// The image is always displayed with aspect-fill so the viewport never shows
/// empty space, and panning/zooming are clamped to keep it that way.
enum ImageCropCalculator {
    /// Scale that makes the image cover (aspect-fill) the viewport at zoom = 1.
    static func baseFillScale(imageSize: CGSize, viewportSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0,
              viewportSize.width > 0, viewportSize.height > 0 else { return 1 }
        return max(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
    }

    /// Clamps a proposed offset so the displayed image always fully covers the viewport,
    /// i.e. the user can never scroll far enough to reveal what's behind the image.
    static func clampedOffset(_ offset: CGSize, displayedImageSize: CGSize, viewportSize: CGSize) -> CGSize {
        let maxX = max(0, (displayedImageSize.width - viewportSize.width) / 2)
        let maxY = max(0, (displayedImageSize.height - viewportSize.height) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    /// The portion of the original image (in the image's own point-space) that is currently
    /// visible inside the viewport, given the zoom/pan used to display it.
    static func visibleRect(imageSize: CGSize, viewportSize: CGSize, effectiveScale: CGFloat, offset: CGSize) -> CGRect {
        guard effectiveScale > 0 else { return CGRect(origin: .zero, size: imageSize) }

        let displayedSize = CGSize(width: imageSize.width * effectiveScale, height: imageSize.height * effectiveScale)
        let imageOriginInViewport = CGPoint(
            x: viewportSize.width / 2 - displayedSize.width / 2 + offset.width,
            y: viewportSize.height / 2 - displayedSize.height / 2 + offset.height
        )
        let visibleInDisplayedImage = CGRect(
            x: -imageOriginInViewport.x,
            y: -imageOriginInViewport.y,
            width: viewportSize.width,
            height: viewportSize.height
        )
        let rect = CGRect(
            x: visibleInDisplayedImage.origin.x / effectiveScale,
            y: visibleInDisplayedImage.origin.y / effectiveScale,
            width: visibleInDisplayedImage.width / effectiveScale,
            height: visibleInDisplayedImage.height / effectiveScale
        )

        let imageBounds = CGRect(origin: .zero, size: imageSize)
        return rect.intersection(imageBounds)
    }
}
