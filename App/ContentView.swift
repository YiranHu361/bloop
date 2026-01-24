import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "gauge")
                }
                .tag(0)

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.bar")
                }
                .tag(1)
        }
        .tint(.indigo)
    }
}

#Preview {
    ContentView()
}
