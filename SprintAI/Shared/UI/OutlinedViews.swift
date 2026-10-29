import SwiftUI

/// A results-sheet palette: paper, ink, and one signal color.
enum SprintTheme {
    static let background = Color(red: 0.965, green: 0.953, blue: 0.925)
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.13)
    static let muted = Color(red: 0.39, green: 0.39, blue: 0.36)
    static let accent = Color(red: 0.72, green: 0.20, blue: 0.11)
    static let rule = Color(red: 0.81, green: 0.80, blue: 0.76)
    // Kept during the screen migration; all surfaces use the same paper.
    static let surface = background
    static let teal = accent
}

enum SprintType {
    static let body = Font.custom("Barlow-Regular", size: 17, relativeTo: .body)
    static let detail = Font.custom("Barlow-Regular", size: 15, relativeTo: .subheadline)
    static let label = Font.custom("Barlow-SemiBold", size: 16, relativeTo: .headline)
    static let caption = Font.custom("Barlow-Medium", size: 12, relativeTo: .caption)
    static let section = Font.custom("Barlow-Medium", size: 23, relativeTo: .title2)
    static func display(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Medium", size: size, relativeTo: .largeTitle)
    }
}

struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SprintType.label)
            .padding(.horizontal, 20).padding(.vertical, 17)
            .frame(minHeight: 54)
            .foregroundStyle(SprintTheme.background)
            .background(SprintTheme.ink.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 2))
    }
}

struct TextActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(SprintType.label)
            .foregroundStyle(SprintTheme.accent)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// Transitional open sections; removed when the screen migration is complete.
struct TrainingCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrainingHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(SprintType.caption).tracking(1.2).foregroundStyle(SprintTheme.accent)
            Text(title).font(SprintType.display(44))
            Text(subtitle).font(SprintType.detail).foregroundStyle(SprintTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
