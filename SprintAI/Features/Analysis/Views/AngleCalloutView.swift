import SwiftUI

struct AngleCalloutView: View {
    let angleDataList: [AngleData]
    let side: AnalysisSide
    let hasMeasurements: Bool

    var body: some View {
        TrainingCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Frame measurements", systemImage: "ruler").font(.headline)
                if let angles = angleDataList.first {
                    HStack {
                        Text("\(side.rawValue) side").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f s", angles.timestamp)).font(.caption.monospacedDigit()).foregroundStyle(SprintTheme.teal)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: 16) {
                        angle("Hip", value: angles.hipAngle)
                        angle("Knee", value: angles.kneeAngle)
                        angle("Torso", value: angles.torsoAngle)
                    }
                    Text("Scrub or pause the video to inspect a different moment.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(hasMeasurements ? "No reliable measurement at this moment. Scrub to a frame where your selected side is visible." : "No reliable angles were detected. Try a well-lit side view with your full body visible, and check the camera-side selection.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func angle(_ title: String, value: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: "%.1f°", value)).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
}
