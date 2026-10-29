import SwiftUI

/// Shared visual language for the training screens.
enum SprintTheme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.085)
    static let surface = Color(red: 0.075, green: 0.10, blue: 0.14)
    static let accent = Color(red: 0.69, green: 0.96, blue: 0.32)
    static let teal = Color(red: 0.25, green: 0.84, blue: 0.80)
}

struct TrainingCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SprintTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.07)))
    }
}

struct TrainingHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(2).foregroundStyle(SprintTheme.accent)
            Text(title).font(.largeTitle.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
