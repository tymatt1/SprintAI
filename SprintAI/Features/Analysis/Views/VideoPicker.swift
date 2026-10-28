import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: VideoPicker
        init(_ parent: VideoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                picker.dismiss(animated: true)
                return
            }
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [parent] url, error in
                do {
                    if let error { throw error }
                    guard let url else { throw ImportError.unavailable }
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent("sprintai-import-\(UUID().uuidString).\(url.pathExtension)")
                    try FileManager.default.copyItem(at: url, to: destination)
                    DispatchQueue.main.async {
                        parent.selectedVideoURL = destination
                        picker.dismiss(animated: true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        parent.onError(error.localizedDescription)
                        picker.dismiss(animated: true)
                    }
                }
            }
        }
    }

    private enum ImportError: LocalizedError {
        case unavailable
        var errorDescription: String? { "The selected video could not be downloaded. Try downloading it in Photos first." }
    }
}
