import SwiftUI
import AVKit

@MainActor
struct AnalysisView: View {
    var isActive = true
    @StateObject var viewModel = AnalysisViewModel()
    @State private var showVideoPicker = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @State private var isSaving = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Workspace { width, wide in
            VStack(alignment: .leading, spacing: 32) {
                Masthead { clipActions }
                if let player = viewModel.annotatedVideoPlayer {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Analysis").font(SprintType.display(48)).accessibilityAddTraits(.isHeader)
                        Spacer()
                        FieldCaption("\(viewModel.measuredSide.rawValue) side")
                    }
                    if wide {
                        HStack(alignment: .top, spacing: 48) {
                            playback(player).frame(width: (width - 48) * 0.65)
                            inspection.frame(maxWidth: .infinity)
                        }
                    } else {
                        playback(player)
                        inspection
                    }
                } else if viewModel.isProcessing {
                    processing
                } else if wide {
                    HStack(alignment: .top, spacing: 80) {
                        importControls.frame(width: (width - 80) * 0.6)
                        guide.padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    importControls
                    DisclosureGroup { guide.padding(.top, 20) } label: {
                        Text("Recording guide").font(SprintType.label)
                    }.tint(SprintTheme.ink).padding(.top, 12)
                }
            }
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(selectedVideoURL: $viewModel.selectedVideoURL) { viewModel.processingError = $0 }
        }
        .alert("Video analysis", isPresented: Binding(get: { viewModel.processingError != nil }, set: { if !$0 { viewModel.processingError = nil } })) {
            Button("OK", role: .cancel) { viewModel.processingError = nil }
        } message: { Text(viewModel.processingError ?? "") }
        .alert("Video export", isPresented: $showSaveAlert) { Button("OK", role: .cancel) {} } message: { Text(saveMessage) }
        .onChange(of: isActive) { _, active in
            if !active { viewModel.annotatedVideoPlayer?.pause(); viewModel.cancelFeedback() }
        }
        .onDisappear {
            viewModel.annotatedVideoPlayer?.pause()
            viewModel.cancelFeedback()
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.annotatedVideoPlayer?.pause() } }
        .onChange(of: viewModel.selectedVideoURL) { _, url in if let url { viewModel.processVideo(url: url) } }
    }

    @ViewBuilder
    private var clipActions: some View {
        if let url = viewModel.annotatedVideoURL {
            Menu {
                Button("Save to Photos", systemImage: "arrow.down.to.line") { saveVideoToPhotos(url: url) }.disabled(isSaving)
                ShareLink(item: url) { Label("Share video", systemImage: "square.and.arrow.up") }
                Button("New clip", systemImage: "plus") { viewModel.clearVideo() }.disabled(isSaving)
            } label: {
                Image(systemName: "ellipsis").font(SprintType.label).frame(width: 44, height: 44)
            }.tint(SprintTheme.ink).accessibilityLabel("Clip options")
        }
    }

    private var importControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Video analysis").font(SprintType.display(64)).accessibilityAddTraits(.isHeader)
            Text("Hip, knee & torso angles from a side view.")
                .font(SprintType.body).foregroundStyle(SprintTheme.muted).padding(.top, 12)
            VStack(alignment: .leading, spacing: 10) {
                FieldCaption("Side facing camera")
                HStack(spacing: 28) {
                    ForEach(AnalysisSide.allCases) { side in
                        Button { viewModel.analysisSide = side } label: {
                            Text(side.rawValue).font(SprintType.label)
                                .foregroundStyle(viewModel.analysisSide == side ? SprintTheme.ink : SprintTheme.muted)
                                .padding(.horizontal, 4).frame(minWidth: 64, minHeight: 44)
                                .overlay(alignment: .bottom) {
                                    if viewModel.analysisSide == side { Rectangle().fill(SprintTheme.accent).frame(height: 2) }
                                }
                        }.buttonStyle(.plain).accessibilityAddTraits(viewModel.analysisSide == side ? .isSelected : [])
                    }
                }
            }.padding(.top, 48)
            Button { showVideoPicker = true } label: {
                HStack { Text("Import video"); Spacer(); Image(systemName: "arrow.up.right") }.frame(maxWidth: .infinity)
            }.buttonStyle(PrimaryActionStyle()).padding(.top, 32)
            Text("Up to 60 seconds · 4096 px per side")
                .font(SprintType.detail).foregroundStyle(SprintTheme.muted).padding(.top, 12)
            Text("Processed on this device.")
                .font(SprintType.caption).foregroundStyle(SprintTheme.muted).padding(.top, 28)
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 24) {
            guideItem("Camera", "Side-on and stationary, with your full body in frame.")
            guideItem("Light", "Use good light to reduce motion blur.")
            guideItem("Length", "Under 20 seconds is recommended.")
        }
    }

    private func guideItem(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(SprintType.label)
            Text(detail).font(SprintType.detail).foregroundStyle(SprintTheme.muted)
        }.accessibilityElement(children: .combine)
    }

    private var processing: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Processing").font(SprintType.display(64)).accessibilityAddTraits(.isHeader)
            Text(viewModel.progress, format: .percent.precision(.fractionLength(0)))
                .font(SprintType.display(100)).monospacedDigit()
            ProgressView(value: viewModel.progress).tint(SprintTheme.accent).accessibilityLabel("Video processing")
            Text("\(viewModel.measuredSide.rawValue) side · pose tracking").font(SprintType.detail).foregroundStyle(SprintTheme.muted)
            Button("Cancel analysis", role: .cancel) { viewModel.clearVideo() }.buttonStyle(TextActionStyle())
        }.frame(maxWidth: 520, alignment: .leading)
    }

    private func playback(_ player: AVPlayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AnalysisVideoPlayer(player: player, onTimeChange: viewModel.updatePlaybackTime)
                .id(viewModel.annotatedVideoURL)
                .aspectRatio(viewModel.videoAspectRatio(), contentMode: .fit)
                .frame(maxHeight: 560)
            Text(isSaving ? "Saving to Photos…" : "Annotated video · no audio")
                .font(SprintType.caption).foregroundStyle(SprintTheme.muted)
        }
    }

    private var inspection: some View {
        VStack(alignment: .leading, spacing: 40) {
            AngleCalloutView(angleDataList: viewModel.displayedAngleData, side: viewModel.measuredSide, hasMeasurements: !viewModel.angleDataList.isEmpty)
            FeedbackInlinePanel(viewModel: viewModel)
        }
    }

    private func saveVideoToPhotos(url: URL) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do { try await VideoSaver.save(url: url); saveMessage = "Video saved to Photos." }
            catch { saveMessage = error.localizedDescription }
            showSaveAlert = true
        }
    }
}
