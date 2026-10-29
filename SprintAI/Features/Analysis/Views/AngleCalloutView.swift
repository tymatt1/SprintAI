import SwiftUI

struct AngleCalloutView: View {
    let angleDataList: [AngleData]
    let side: AnalysisSide
    let hasMeasurements: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Measurements").font(SprintType.section).accessibilityAddTraits(.isHeader)
                Spacer()
                if let angles = angleDataList.first {
                    Text(String(format: "%.2f s", angles.timestamp)).font(SprintType.caption).monospacedDigit().foregroundStyle(SprintTheme.muted)
                }
            }
            if let angles = angleDataList.first {
                VStack(spacing: 4) {
                    angle("Hip", value: angles.hipAngle)
                    angle("Knee", value: angles.kneeAngle)
                    angle("Torso", value: angles.torsoAngle)
                }
            } else {
                Text(hasMeasurements ? "No reliable pose in this frame." : "No reliable angles detected. Check camera side and full-body visibility.")
                    .font(SprintType.detail).foregroundStyle(SprintTheme.muted)
            }
        }
    }

    private func angle(_ title: String, value: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(SprintType.body).foregroundStyle(SprintTheme.muted)
            Spacer()
            Text(String(format: "%.1f°", value)).font(SprintType.display(40)).monospacedDigit()
        }.frame(minHeight: 48).accessibilityElement(children: .combine)
    }
}
