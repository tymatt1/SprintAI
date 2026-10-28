import SwiftUI

struct AngleCalloutView: View {
    var angleDataList: [AngleData]
    @Binding var dataHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                Text("Angles")
                    .font(.headline)
                    .bold()
                Spacer()
            }
            .foregroundColor(.white)

            AngleDataChart(angleDataList: angleDataList, dataHeight: $dataHeight)
                .frame(height: min(dataHeight, 260))
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}


struct AngleDataChart: View {
    var angleDataList: [AngleData]
    @Binding var dataHeight: CGFloat

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Row
                HStack {
                    Text("Hip Angle")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                    Text("Knee Angle")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                    Text("Torso Angle")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.black)

                // Data Rows
                ForEach(angleDataList) { angleData in
                    HStack(spacing: 0) {
                        AngleCell(angle: angleData.hipAngle)
                        AngleCell(angle: angleData.kneeAngle)
                        AngleCell(angle: angleData.torsoAngle)
                    }
                    .padding(.vertical, 5)
                    .background(Color.black)
                }
            }
        }
        .frame(height: dataHeight)
        .background(Color.black)
    }
}

struct AngleCell: View {
    var angle: CGFloat
    var body: some View {
        Text(String(format: "%.1f°", angle))
            .monospacedDigit()
            .padding(5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
    }
}
