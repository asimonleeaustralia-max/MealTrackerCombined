import SwiftUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers

struct CameraCaptureView: UIViewControllerRepresentable {
    struct Payload {
        let data: Data
        let suggestedExt: String? // "jpg" or "heic" typically
    }

    enum CaptureError: LocalizedError {
        case cameraUnavailable
        case permissionDenied
        case exportFailed
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return NSLocalizedString("camera_unavailable_error", comment: "")
            case .permissionDenied: return NSLocalizedString("camera_permission_denied_error", comment: "")
            case .exportFailed: return NSLocalizedString("camera_export_failed_error", comment: "")
            }
        }
    }

    typealias Completion = (Result<Payload, Error>?) -> Void

    let completion: Completion

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.allowsEditing = false
            // Prefer HEIC if available; UIImagePickerController will decide actual format.
        } else {
            // If camera not available, immediately return an error
            DispatchQueue.main.async {
                completion(.failure(CaptureError.cameraUnavailable))
            }
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: Completion

        init(completion: @escaping Completion) {
            self.completion = completion
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.completion(nil)
            }
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Prefer original image
            if let image = info[ .originalImage ] as? UIImage {
                let suggestedExt = "jpg"
                if let data = image.jpegData(compressionQuality: 0.95) {
                    picker.dismiss(animated: true) {
                        self.completion(.success(Payload(data: data, suggestedExt: suggestedExt)))
                    }
                    return
                }
            }

            picker.dismiss(animated: true) {
                self.completion(.failure(CaptureError.exportFailed))
            }
        }
    }
}

