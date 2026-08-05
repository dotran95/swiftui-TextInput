//
//  ChatBackgroundPickerView.swift
//  app
//

import SwiftUI

/// Entry point for choosing a chat detail background: pick a photo from the library,
/// then frame it with `ChatBackgroundImagePreviewView` before handing back the crop.
struct ChatBackgroundPickerView: View {
    var onFinish: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var pickedImage: UIImage?
    @State private var isPickerPresented = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let pickedImage {
                ChatBackgroundImagePreviewView(
                    image: pickedImage,
                    onSave: onFinish,
                    onCancel: onCancel
                )
            }
        }
        .sheet(isPresented: $isPickerPresented, onDismiss: {
            if pickedImage == nil {
                onCancel()
            }
        }) {
            PhotoPicker(
                onPick: { image in
                    pickedImage = image
                    isPickerPresented = false
                },
                onCancel: {
                    isPickerPresented = false
                }
            )
            .ignoresSafeArea()
        }
    }
}
