import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TimingView()
                .tabItem { Label("Timing", systemImage: "timer") }
            AnalysisView()
                .tabItem { Label("Analysis", systemImage: "figure.run") }
            FeedbackSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.green)
    }
}
