//
//  ChatBackgroundImagePreviewView.swift
//  app
//

import SwiftUI

/// Lets the user pinch-zoom and pan a photo to frame it as a chat background.
/// The image always fills the viewport (aspect-fill), and zoom/pan are clamped so the
/// user can never scroll past the image edges into empty space. Saving crops exactly the
/// region currently shown on screen.
struct ChatBackgroundImagePreviewView: View {
    let image: UIImage
    var onSave: (UIImage) -> Void
    var onCancel: () -> Void

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 5

    @State private var committedZoom: CGFloat = 1
    @State private var committedOffset: CGSize = .zero
    @GestureState private var gestureZoomDelta: CGFloat = 1
    @GestureState private var gestureTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let baseScale = ImageCropCalculator.baseFillScale(imageSize: image.size, viewportSize: viewportSize)
            let liveZoom = min(max(committedZoom * gestureZoomDelta, minZoom), maxZoom)
            let effectiveScale = baseScale * liveZoom
            let displayedSize = CGSize(
                width: image.size.width * effectiveScale,
                height: image.size.height * effectiveScale
            )
            let rawOffset = CGSize(
                width: committedOffset.width + gestureTranslation.width,
                height: committedOffset.height + gestureTranslation.height
            )
            let liveOffset = ImageCropCalculator.clampedOffset(
                rawOffset,
                displayedImageSize: displayedSize,
                viewportSize: viewportSize
            )

            ZStack {
                Color.black

                Image(uiImage: image)
                    .resizable()
                    .frame(width: displayedSize.width, height: displayedSize.height)
                    .offset(liveOffset)
                    .frame(width: viewportSize.width, height: viewportSize.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .updating($gestureZoomDelta) { value, state, _ in
                                    state = value
                                }
                                .onEnded { value in
                                    let newZoom = min(max(committedZoom * value, minZoom), maxZoom)
                                    let newDisplayedSize = CGSize(
                                        width: image.size.width * baseScale * newZoom,
                                        height: image.size.height * baseScale * newZoom
                                    )
                                    committedOffset = ImageCropCalculator.clampedOffset(
                                        committedOffset,
                                        displayedImageSize: newDisplayedSize,
                                        viewportSize: viewportSize
                                    )
                                    committedZoom = newZoom
                                },
                            DragGesture()
                                .updating($gestureTranslation) { value, state, _ in
                                    state = value.translation
                                }
                                .onEnded { value in
                                    let newOffset = CGSize(
                                        width: committedOffset.width + value.translation.width,
                                        height: committedOffset.height + value.translation.height
                                    )
                                    committedOffset = ImageCropCalculator.clampedOffset(
                                        newOffset,
                                        displayedImageSize: displayedSize,
                                        viewportSize: viewportSize
                                    )
                                }
                        )
                    )

                controls(effectiveScale: effectiveScale, liveOffset: liveOffset, viewportSize: viewportSize)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func controls(effectiveScale: CGFloat, liveOffset: CGSize, viewportSize: CGSize) -> some View {
        VStack {
            Spacer()
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    let visibleRect = ImageCropCalculator.visibleRect(
                        imageSize: image.size,
                        viewportSize: viewportSize,
                        effectiveScale: effectiveScale,
                        offset: liveOffset
                    )
                    onSave(image.cropped(to: visibleRect) ?? image)
                } label: {
                    Text("Save")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}
