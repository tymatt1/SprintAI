import SwiftUI

struct ContentView: View {
    private enum Screen: String, CaseIterable {
        case timing = "Timing", analysis = "Analysis", settings = "Settings"
        var icon: String {
            switch self { case .timing: "stopwatch"; case .analysis: "viewfinder"; case .settings: "slider.horizontal.3" }
        }
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selection: Screen = .timing

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TimingView(isActive: selection == .timing).workspaceVisible(selection == .timing)
                AnalysisView(isActive: selection == .analysis).workspaceVisible(selection == .analysis)
                FeedbackSettingsView().workspaceVisible(selection == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            navigation
        }
        .font(SprintType.body).foregroundStyle(SprintTheme.ink)
        .tint(SprintTheme.accent).background(SprintTheme.background)
        .preferredColorScheme(.light)
        .onChange(of: selection) { _, _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var navigation: some View {
        Group {
            if typeSize.isAccessibilitySize {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 28) {
                            ForEach(Screen.allCases, id: \.self) { screen in
                                navigationButton(screen).id(screen)
                            }
                        }.padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: selection) { _, screen in proxy.scrollTo(screen, anchor: .center) }
                }.fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 0) {
                    ForEach(Screen.allCases, id: \.self) { screen in
                        navigationButton(screen).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 16)
            }
        }
        .padding(.top, 4).background(SprintTheme.background)
        .overlay(alignment: .top) { Hairline() }
        .accessibilityElement(children: .contain).accessibilityLabel("Navigation")
    }

    private func navigationButton(_ screen: Screen) -> some View {
        Button { selection = screen } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    Text(screen.rawValue).font(SprintType.label).fixedSize().padding(.vertical, 12)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: screen.icon).font(SprintType.label)
                        Text(screen.rawValue).font(SprintType.caption)
                    }
                }
            }
            .foregroundStyle(selection == screen ? SprintTheme.accent : SprintTheme.muted)
            .frame(minHeight: 62).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == screen ? .isSelected : [])
    }

}

private extension View {
    func workspaceVisible(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .zIndex(visible ? 1 : 0)
    }
}
