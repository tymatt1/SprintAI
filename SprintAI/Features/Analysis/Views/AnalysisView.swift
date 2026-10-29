import SwiftUI
import AVKit

@MainActor
struct AnalysisView: View {
    @StateObject var viewModel = AnalysisViewModel()
    @State private var showVideoPicker = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @State private var isSaving = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrainingHeader(eyebrow: "SprintAI · Motion lab", title: "Find your next edge.", subtitle: "See your mechanics. Understand your movement.")
                    if let player = viewModel.annotatedVideoPlayer {
                        result(player: player)
                    } else if viewModel.isProcessing {
                        processingCard
                    } else {
                        importCard
                        filmingGuide
                    }
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(SprintTheme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(selectedVideoURL: $viewModel.selectedVideoURL) { viewModel.processingError = $0 }
        }
        .alert("Video analysis", isPresented: Binding(get: { viewModel.processingError != nil }, set: { if !$0 { viewModel.processingError = nil } })) {
            Button("OK", role: .cancel) { viewModel.processingError = nil }
        } message: { Text(viewModel.processingError ?? "") }
        .alert("Video export", isPresented: $showSaveAlert) { Button("OK", role: .cancel) {} } message: { Text(saveMessage) }
        .onDisappear {
            viewModel.annotatedVideoPlayer?.pause()
            viewModel.cancelFeedback()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.annotatedVideoPlayer?.pause() }
        }
        .onChange(of: viewModel.selectedVideoURL) { _, url in
            if let url { viewModel.processVideo(url: url) }
        }
    }

    private var importCard: some View {
        TrainingCard {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "figure.run.square.stack.fill")
                    .font(.system(size: 52, weight: .light)).foregroundStyle(SprintTheme.teal)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("A new perspective on your sprint.").font(.title2.bold())
                    Text("Import a side-view clip to add a pose overlay and inspect hip, knee, and torso angles.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Side facing the camera").font(.subheadline.weight(.medium))
                    Picker("Side facing the camera", selection: $viewModel.analysisSide) {
                        ForEach(AnalysisSide.allCases) { side in Text(side.rawValue).tag(side) }
                    }.pickerStyle(.segmented)
                }
                Button { showVideoPicker = true } label: {
                    Label("Choose a video", systemImage: "plus")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent).tint(SprintTheme.accent).foregroundStyle(SprintTheme.background)
                Label("Pose analysis stays on your device", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var filmingGuide: some View {
        TrainingCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Set up a better shot").font(.headline)
                guideRow("01", title: "Film from the side", detail: "Keep the camera still and perpendicular to your direction of travel.")
                guideRow("02", title: "Keep your whole body in frame", detail: "Leave room above your head and below your feet. Good light helps reduce blur.")
                guideRow("03", title: "Keep it short", detail: "Under 20 seconds works best. Maximum: 60 seconds and 4096 pixels per side.")
            }
        }
    }

    private func guideRow(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.caption.bold()).monospacedDigit().foregroundStyle(SprintTheme.teal).padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }

    private var processingCard: some View {
        TrainingCard {
            VStack(alignment: .leading, spacing: 20) {
                Label("Analyzing your movement", systemImage: "figure.run").font(.title2.bold())
                Text("Building a pose overlay and measuring your \(viewModel.measuredSide.rawValue.lowercased()) side. Longer clips take more time.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ProgressView(value: viewModel.progress).tint(SprintTheme.accent)
                    .accessibilityLabel("Video processing")
                Text(viewModel.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.monospacedDigit()).foregroundStyle(SprintTheme.accent)
                Button("Cancel analysis", role: .cancel) { viewModel.clearVideo() }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private func result(player: AVPlayer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Analysis ready", systemImage: "checkmark.circle.fill").foregroundStyle(SprintTheme.teal).font(.subheadline)
                Spacer()
                Button("New clip", systemImage: "plus") { viewModel.clearVideo() }
                    .frame(minHeight: 44).disabled(isSaving)
            }
            AnalysisVideoPlayer(player: player, onTimeChange: viewModel.updatePlaybackTime)
                .id(viewModel.annotatedVideoURL)
                .aspectRatio(viewModel.videoAspectRatio(), contentMode: .fit)
                .frame(maxHeight: 480)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            if let url = viewModel.annotatedVideoURL {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { exportButton(url); ShareLink(item: url) { Label("Share video", systemImage: "square.and.arrow.up").frame(minHeight: 44) } }
                    VStack(alignment: .leading) { exportButton(url); ShareLink(item: url) { Label("Share video", systemImage: "square.and.arrow.up").frame(minHeight: 44) } }
                }
                .font(.subheadline.weight(.semibold)).tint(SprintTheme.teal)
            }
            Text("Export includes the pose overlay. Source audio is not included.")
                .font(.caption).foregroundStyle(.secondary)
        }
        AngleCalloutView(angleDataList: viewModel.displayedAngleData, side: viewModel.measuredSide, hasMeasurements: !viewModel.angleDataList.isEmpty)
        FeedbackInlinePanel(viewModel: viewModel)
        Text("Angles are 2D estimates. Camera position, visibility, and stride phase affect the measurement.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func exportButton(_ url: URL) -> some View {
        Button { saveVideoToPhotos(url: url) } label: {
            Label(isSaving ? "Saving…" : "Save to Photos", systemImage: "arrow.down.to.line").frame(minHeight: 44)
        }.disabled(isSaving)
    }

    private func saveVideoToPhotos(url: URL) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await VideoSaver.save(url: url)
                saveMessage = "Your annotated video was saved to Photos."
            } catch { saveMessage = error.localizedDescription }
            showSaveAlert = true
        }
    }
}
