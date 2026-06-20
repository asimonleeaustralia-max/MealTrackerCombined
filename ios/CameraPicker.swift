//
//  CameraPicker.swift
//  MealTracker
//
//  A SwiftUI wrapper for UIImagePickerController (camera).
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel?()
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Prefer original image data if available; otherwise build JPEG from UIImage
            var outData: Data?

            if let imageURL = info[.imageURL] as? URL, let data = try? Data(contentsOf: imageURL) {
                outData = data
            } else if let image = info[.originalImage] as? UIImage {
                // Preserve quality if possible; use JPEG as a fallback
                if let jpeg = image.jpegData(compressionQuality: 0.95) {
                    outData = jpeg
                }
            }

            if let data = outData {
                parent.onImageData(data)
            } else {
                parent.onError?("Failed to capture image data.")
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    @Environment(\.presentationMode) private var presentationMode

    // Callbacks
    let onImageData: (Data) -> Void
    var onCancel: (() -> Void)? = nil
    var onError: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // no-op
    }
}
