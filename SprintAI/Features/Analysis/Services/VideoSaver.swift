import Photos
import Foundation

enum VideoSaver {
    static func save(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.permission }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    private enum SaveError: LocalizedError {
        case permission
        var errorDescription: String? { "Allow SprintAI to add videos in Settings → Privacy & Security → Photos." }
    }
}
