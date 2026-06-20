import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import ImageIO
import MobileCoreServices

struct PhotoLibraryPickerViewV2: UIViewControllerRepresentable {
    struct Payload {
        let data: Data
        let suggestedExt: String? // "jpg", "heic", or "png"
    }

    enum PickError: LocalizedError {
        case exportFailed
        var errorDescription: String? {
            switch self {
            case .exportFailed: return NSLocalizedString("photo_export_failed_error", comment: "")
            }
        }
    }

    typealias Completion = (Result<Payload, Error>?) -> Void

    let completion: Completion

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        if #available(iOS 14.0, *) {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = false
            picker.delegate = context.coordinator
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate {
        let completion: Completion

        init(completion: @escaping Completion) {
            self.completion = completion
        }

        // iOS 14+ path
        @available(iOS 14.0, *)
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let item = results.first else {
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) { self.completion(nil) }
                }
                return
            }

            let provider = item.itemProvider

            func finishWithData(_ data: Data, ext: String?) {
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) {
                        self.completion(.success(Payload(data: data, suggestedExt: ext)))
                    }
                }
            }

            // Prefer loading as Data in original type if possible
            let targetTypes: [UTType] = {
                if #available(iOS 14.0, *) {
                    return [UTType.heic, UTType.jpeg, UTType.png]
                } else {
                    return []
                }
            }()

            // Try HEIC/JPEG/PNG in order without recompressing
            for t in targetTypes {
                if provider.hasItemConformingToTypeIdentifier(t.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: t.identifier) { data, _ in
                        if let data = data {
                            let ext: String? = {
                                if t == .heic { return "heic" }
                                if t == .jpeg { return "jpg" }
                                if t == .png { return "png" }
                                return nil
                            }()
                            finishWithData(data, ext: ext)
                        } else {
                            // Fall back to UIImage path
                            self.loadAsUIImage(provider: provider, picker: picker)
                        }
                    }
                    return
                }
            }

            // Fallback: load as UIImage and export JPEG
            loadAsUIImage(provider: provider, picker: picker)
        }

        @available(iOS 14.0, *)
        private func loadAsUIImage(provider: NSItemProvider, picker: PHPickerViewController) {
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.95) else {
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.completion(.failure(PickError.exportFailed))
                            }
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true) {
                            self.completion(.success(Payload(data: data, suggestedExt: "jpg")))
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) {
                        self.completion(.failure(PickError.exportFailed))
                    }
                }
            }
        }

        // iOS 13 fallback path
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.completion(nil) }
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer { picker.dismiss(animated: true, completion: nil) }
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.95) {
                completion(.success(Payload(data: data, suggestedExt: "jpg")))
            } else {
                completion(.failure(PickError.exportFailed))
            }
        }
    }
}
