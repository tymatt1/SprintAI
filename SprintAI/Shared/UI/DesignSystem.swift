import SwiftUI

/// A results-sheet palette: paper, ink, and one signal color.
enum SprintTheme {
    static let background = Color(red: 0.965, green: 0.953, blue: 0.925)
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.13)
    static let muted = Color(red: 0.39, green: 0.39, blue: 0.36)
    static let accent = Color(red: 0.72, green: 0.20, blue: 0.11)
    static let rule = Color(red: 0.81, green: 0.80, blue: 0.76)
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

struct Workspace<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: (CGFloat, Bool) -> Content
    init(@ViewBuilder content: @escaping (CGFloat, Bool) -> Content) { self.content = content }

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = geometry.size.width < 600 ? 24 : 40
            let width = max(0, min(geometry.size.width, 1120) - inset * 2)
            ScrollView {
                content(width, width >= 740 && !typeSize.isAccessibilitySize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, inset).padding(.top, 16).padding(.bottom, 40)
                    .frame(maxWidth: 1120).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SprintTheme.background)
        }
        .font(SprintType.body).foregroundStyle(SprintTheme.ink)
    }
}

struct Masthead<Actions: View>: View {
    let actions: Actions
    init(@ViewBuilder actions: () -> Actions) { self.actions = actions() }
    var body: some View {
        HStack {
            Text("SPRINTAI").font(SprintType.display(26)).tracking(1)
                .accessibilityLabel("Sprint AI")
            Spacer()
            actions
        }.frame(minHeight: 44)
    }
}

struct FieldCaption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(SprintType.caption).tracking(0.9).foregroundStyle(SprintTheme.muted)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(SprintTheme.rule).frame(height: 0.5).accessibilityHidden(true) }
}
