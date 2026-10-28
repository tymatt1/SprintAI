import AVFoundation
import SwiftUI

@MainActor
final class AnalysisViewModel: ObservableObject {
    @Published var analysisSide: AnalysisSide = .right
    @Published private(set) var measuredSide: AnalysisSide = .right
    @Published var selectedVideoURL: URL?
    @Published private(set) var annotatedVideoPlayer: AVPlayer?
    @Published private(set) var annotatedVideoURL: URL?
    @Published private(set) var isProcessing = false
    @Published private(set) var progress = 0.0
    @Published private(set) var angleDataList: [AngleData] = []
    @Published private(set) var displayedAngleData: [AngleData] = []
    @Published private(set) var isGeneratingFeedback = false
    @Published private(set) var feedbackText: String?
    @Published private(set) var feedbackError: String?
    @Published var processingError: String?
    @Published private(set) var currentStage: FeedbackStage?
    @Published private(set) var stageStatuses: [FeedbackStage: Status] = [:]

    enum FeedbackStage: String, CaseIterable {
        case extracting = "Extracting frames"
        case sending = "Getting AI response"
        case done = "Done"
    }
    enum Status { case pending, running, done, error }

    private var processingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var videoID = UUID()
    private var feedbackID = UUID()
    private var measurementTimes: [Double] = []
    private var sourceVideoURL: URL?
    private var aspectRatio: CGFloat = 16 / 9

    func processVideo(url: URL) {
        clearVideo(preservingSelection: true)
        sourceVideoURL = url
        isProcessing = true
        let jobID = videoID
        let side = analysisSide
        measuredSide = side
        processingTask = Task { [weak self] in
            do {
                let result = try await VideoProcessor.process(url: url, side: side) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard self?.videoID == jobID else { return }
                        self?.progress = progress
                    }
                }
                guard let self, self.videoID == jobID, !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: result.url)
                    return
                }
                self.annotatedVideoURL = result.url
                self.angleDataList = result.angles
                self.measurementTimes = result.angles.map(\.timestamp)
                self.aspectRatio = result.aspectRatio
                try Task.checkCancellation()
                guard self.videoID == jobID else { return }
                self.annotatedVideoPlayer = AVPlayer(url: result.url)
                self.isProcessing = false
                self.progress = 1
            } catch {
                guard let self, self.videoID == jobID else { return }
                self.isProcessing = false
                if !(error is CancellationError) { self.processingError = error.localizedDescription }
            }
        }
    }

    func updatePlaybackTime(_ time: Double) {
        if let index = PlaybackSampleSelector.index(at: time, in: measurementTimes) {
            displayedAngleData = [angleDataList[index]]
        } else {
            displayedAngleData = []
        }
    }

    func generateFormFeedback() {
        guard !isGeneratingFeedback, let url = sourceVideoURL else { return }
        feedbackError = nil
        feedbackText = nil
        isGeneratingFeedback = true
        stageStatuses = Dictionary(uniqueKeysWithValues: FeedbackStage.allCases.map { ($0, .pending) })
        let requestID = UUID()
        feedbackID = requestID
        let angles = angleDataList
        let side = measuredSide
        feedbackTask = Task { [weak self] in
            do {
                self?.setStage(.extracting, .running)
                let frames = try await FeedbackFrameExtractor.extract(url: url, angles: angles)
                try Task.checkCancellation()
                guard let self, self.feedbackID == requestID else { return }
                self.setStage(.extracting, .done)
                self.setStage(.sending, .running)
                let feedback = try await FeedbackClient().generate(frames: frames, context: Self.context(for: angles, side: side))
                try Task.checkCancellation()
                guard self.feedbackID == requestID else { return }
                self.feedbackText = feedback
                self.setStage(.sending, .done)
                self.setStage(.done, .done)
                self.isGeneratingFeedback = false
            } catch {
                guard let self, self.feedbackID == requestID else { return }
                self.isGeneratingFeedback = false
                if !(error is CancellationError) && (error as? URLError)?.code != .cancelled {
                    self.feedbackError = error.localizedDescription
                    self.setStage(self.currentStage ?? .extracting, .error)
                }
            }
        }
    }

    func cancelFeedback() {
        feedbackID = UUID()
        feedbackTask?.cancel()
        feedbackTask = nil
        isGeneratingFeedback = false
        currentStage = nil
        stageStatuses = [:]
    }

    func clearVideo(preservingSelection: Bool = false) {
        videoID = UUID()
        processingTask?.cancel()
        processingTask = nil
        cancelFeedback()
        annotatedVideoPlayer?.pause()
        annotatedVideoPlayer = nil
        if let url = annotatedVideoURL { try? FileManager.default.removeItem(at: url) }
        // Only remove files owned by this app's picker.
        if let url = sourceVideoURL, url.lastPathComponent.hasPrefix("sprintai-import-") {
            try? FileManager.default.removeItem(at: url)
        }
        sourceVideoURL = nil
        annotatedVideoURL = nil
        if !preservingSelection { selectedVideoURL = nil }
        measurementTimes = []
        angleDataList = []
        displayedAngleData = []
        feedbackText = nil
        feedbackError = nil
        processingError = nil
        isProcessing = false
        progress = 0
    }

    func videoAspectRatio() -> CGFloat { aspectRatio }

    private func setStage(_ stage: FeedbackStage, _ status: Status) {
        currentStage = stage
        stageStatuses[stage] = status
    }

    private static func context(for angles: [AngleData], side: AnalysisSide) -> String? {
        guard !angles.isEmpty else { return nil }
        func summary(_ values: [CGFloat]) -> String {
            let mean = values.reduce(0, +) / CGFloat(values.count)
            return String(format: "mean %.1f°, range %.1f–%.1f°", mean, values.min()!, values.max()!)
        }
        return """
        2D side-view measurements; hip, knee, and torso use the \(side.rawValue.lowercased()) side. These are estimates, not calibrated biomechanics.
        Torso angle from vertical: \(summary(angles.map(\.torsoAngle))).
        Hip interior angle: \(summary(angles.map(\.hipAngle))).
        Knee interior angle: \(summary(angles.map(\.kneeAngle))).
        """
    }
}
