//
//  AnalysisView.swift
//  SprintTimer
//
//  Created by Matthew Tybur on 11/19/24.
//  Updated with AI feedback + Angles callout on 09/11/25
//

import SwiftUI
import AVKit

@MainActor
struct AnalysisView: View {
    @StateObject var viewModel = AnalysisViewModel()
    @State private var showVideoPicker = false
    @State private var dataHeight: CGFloat = 205
    @State private var bobAnimation = false

    // Toggle to show/hide angles callout
    @State private var showAnglesCallout = false

    // For save operation feedback
    @State private var showSaveAlert = false
    @State private var saveError: Error?

    var body: some View {
        ZStack {
            if let player = viewModel.annotatedVideoPlayer {
                // MAIN VIDEO + ANGLES LAYOUT
                VStack(spacing: 12) {
                    // Header row with angle toggle
                    HStack {
                        Text("Sprint Analysis")
                            .font(.title3).bold()
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                showAnglesCallout.toggle()
                            }
                        } label: {
                            Label("Angles", systemImage: "chart.xyaxis.line")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Video + close/save controls
                    let aspectRatio = viewModel.videoAspectRatio()
                    let isVertical = aspectRatio < 1.0

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            // 'X' Button
                            Button(action: {
                                dataHeight = 205
                                // Clear video ALSO clears AI feedback
                                viewModel.clearVideo()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .padding(.top, isVertical ? 12 : 8)
                            }

                            // Save Button
                            if let annotatedURL = viewModel.annotatedVideoURL {
                                Button(action: {
                                    saveVideoToPhotos(url: annotatedURL)
                                }) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        if isVertical {
                            // For vertical videos
                            let videoHeight: CGFloat = 350
                            let videoWidth = videoHeight * aspectRatio

                            AnalysisVideoPlayer(player: player, onTimeChange: viewModel.updatePlaybackTime)
                                .frame(width: videoWidth, height: videoHeight)
                                .cornerRadius(16)
                                .clipped()
                                .onAppear {
                                    player.play()
                                }
                        } else {
                            // For horizontal (landscape) videos
                            AnalysisVideoPlayer(player: player, onTimeChange: viewModel.updatePlaybackTime)
                                .aspectRatio(aspectRatio, contentMode: .fit)
                                .cornerRadius(16)
                                .clipped()
                                .onAppear {
                                    dataHeight = 400
                                    player.play()
                                }
                        }
                    }
                    .transition(.opacity)
                    .padding(.horizontal, 16)

                    // ANGLES CALLOUT (appears when toggled)
                    if showAnglesCallout {
                        AngleCalloutView(
                            angleDataList: viewModel.displayedAngleData,
                            dataHeight: $dataHeight
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
                .background(Color.black.ignoresSafeArea())
                .animation(.easeInOut(duration: 0.5), value: viewModel.isProcessing)
                .animation(.easeInOut(duration: 0.5), value: viewModel.annotatedVideoPlayer)
                .alert(isPresented: $showSaveAlert) {
                    if let error = saveError {
                        return Alert(
                            title: Text("Save Error"),
                            message: Text(error.localizedDescription),
                            dismissButton: .default(Text("OK"))
                        )
                    } else {
                        return Alert(
                            title: Text("Saved!"),
                            message: Text("Your video was saved to the Photo Library."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
                // Feedback panel is an overlay at the bottom of this screen,
                // not part of the VStack flow.
                .overlay(alignment: .bottom) {
                    if !showAnglesCallout {
                        FeedbackInlinePanel(viewModel: viewModel)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)   // keeps it above the tab bar
                    }
                }

            } else if viewModel.isProcessing {
                // PROCESSING view (not scrollable)
                Color.black
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer(minLength: 150)
                    OutlinedText(
                        text: "Processing Video...",
                        font: .headline,
                        fillColor: .white,
                        strokeColor: .blue,
                        lineWidth: 0.3
                    )
                    .padding(.bottom, 20)

                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .padding(.horizontal, 40)
                        .scaleEffect(x: 1, y: 2, anchor: .center)

                    Button("Cancel") { viewModel.clearVideo() }
                        .padding()
                    Spacer()
                }
                .transition(.opacity)
            } else {
                // INITIAL VIEW (non-scrollable)
                Color.black
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer(minLength: 150)
                    OutlinedImage(
                        systemName: "figure.run.circle.fill",
                        size: 150,
                        fillColor: .white.opacity(0.8),
                        strokeColor: .green,
                        lineWidth: 0.8
                    )
                    .padding(.bottom, 20)

                    OutlinedText(
                        text: "Sprint Analysis",
                        font: .largeTitle,
                        weight: .bold,
                        fillColor: .white,
                        strokeColor: .green,
                        lineWidth: 0.3
                    )
                    OutlinedText(
                        text: "Tap to input a video.\n\nRecommended: under 20 seconds, camera on the athlete’s right side. Maximum length: 60 seconds.",
                        font: .headline,
                        fillColor: .white,
                        strokeColor: .green,
                        lineWidth: 0.3
                    )
                    .padding(10)
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding()
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Choose a sprint video")
                .accessibilityHint("Select a side-view clip up to 60 seconds long")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { showVideoPicker = true }
                .onTapGesture {
                    showVideoPicker = true
                }
                .transition(.opacity)
                .scaleEffect(bobAnimation ? 1.02 : 0.98)
                .animation(
                    Animation
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: bobAnimation
                )
                .onAppear {
                    bobAnimation = true
                }
            }
        }
        // Video picker
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(selectedVideoURL: $viewModel.selectedVideoURL) { viewModel.processingError = $0 }
        }
        .alert("Video analysis", isPresented: Binding(
            get: { viewModel.processingError != nil },
            set: { if !$0 { viewModel.processingError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.processingError = nil }
        } message: {
            Text(viewModel.processingError ?? "")
        }
        .onDisappear {
            viewModel.annotatedVideoPlayer?.pause()
            viewModel.cancelFeedback()
        }
        .onChange(of: viewModel.selectedVideoURL) { _, newURL in
            if let url = newURL {
                viewModel.processVideo(url: url)
            }
        }
    }

    private func saveVideoToPhotos(url: URL) {
        Task {
            do {
                try await VideoSaver.save(url: url)
                saveError = nil
            } catch { saveError = error }
            showSaveAlert = true
        }
    }
}
