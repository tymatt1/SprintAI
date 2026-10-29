import Charts
import SwiftUI

struct SprintChartView: View {
    @ObservedObject var viewModel: SprintTimerViewModel
    @Binding var selectedRecord: SprintTimeRecord?

    private var records: [SprintTimeRecord] { viewModel.filteredSprintTimes() }
    private var series: [Series] {
        Dictionary(grouping: records, by: \.colorID).map { key, values in
            Series(id: key, color: values.first?.color ?? .blue, records: values.sorted { $0.date < $1.date })
        }.sorted { $0.id < $1.id }
    }

    var body: some View {
        ScrollView(.horizontal) {
            Chart {
                ForEach(series) { series in
                    ForEach(series.records) { record in
                        if series.records.count > 1 {
                            LineMark(x: .value("Recorded", record.date), y: .value("Seconds", record.time), series: .value("Series", series.id))
                                .foregroundStyle(series.color)
                        }
                        PointMark(x: .value("Recorded", record.date), y: .value("Seconds", record.time))
                            .symbol {
                                let selected = record.id == selectedRecord?.id
                                CircleSymbol(color: record.color, isSelected: selected, size: selected ? 16 : 8)
                            }
                            .annotation(position: .top) {
                                if record.id == selectedRecord?.id { AnnotationView(record: record) }
                            }
                    }
                }
            }
            .chartXScale(domain: xAxisDomain(records: records))
            .chartYScale(domain: yAxisDomain(records: records))
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .frame(width: max(240, min(1600, CGFloat(records.count) * 50)), height: 230)
            .padding(.top, 24)
            .padding(.horizontal, 8)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in select(at: location, proxy: proxy, geometry: geometry) }
                }
            }
        }
        .overlay {
            if records.isEmpty {
                Text("Your detected sprints will appear here.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
        }
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let anchor = proxy.plotFrame else { return }
        let frame = geometry[anchor]
        let tap = CGPoint(x: location.x - frame.minX, y: location.y - frame.minY)
        // Compare distances in screen pixels, rather than mixing seconds on two data axes.
        let candidates = records.compactMap { record -> (SprintTimeRecord, CGFloat)? in
            guard let x = proxy.position(forX: record.date), let y = proxy.position(forY: record.time) else { return nil }
            return (record, hypot(x - tap.x, y - tap.y))
        }
        guard frame.contains(location), let nearest = candidates.min(by: { $0.1 < $1.1 }), nearest.1 <= 30 else {
            selectedRecord = nil
            return
        }
        selectedRecord = selectedRecord?.id == nearest.0.id ? nil : nearest.0
    }

    private struct Series: Identifiable {
        let id: String
        let color: Color
        let records: [SprintTimeRecord]
    }
}

private extension SprintTimeRecord {
    var colorID: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return "unknown" }
        return [r, g, b, a].map { String(format: "%.3f", $0) }.joined(separator: "-")
    }
}
