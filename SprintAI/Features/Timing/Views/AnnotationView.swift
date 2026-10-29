import SwiftUI

struct AnnotationView: View {
    let record: SprintTimeRecord
    var body: some View {
        Text(String(format: "%.2f s", record.time))
            .font(SprintType.label).monospacedDigit()
            .foregroundStyle(SprintTheme.ink)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(SprintTheme.background)
    }
}
