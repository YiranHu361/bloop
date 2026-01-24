import SwiftUI

/// Main content view - initial prototype
struct ContentView: View {
    @State private var dosePercent: Double = 0
    @State private var isAuthorized = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Simple dose display
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 20)

                    Circle()
                        .trim(from: 0, to: min(dosePercent / 100, 1.0))
                        .stroke(
                            dosePercent < 50 ? Color.green :
                            dosePercent < 80 ? Color.orange : Color.red,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(Int(dosePercent))%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))

                        Text("Daily Dose")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 200, height: 200)
                .padding(.top, 40)

                // Status text
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(statusColor)

                Spacer()

                // Authorization button
                if !isAuthorized {
                    Button("Request HealthKit Access") {
                        Task {
                            await requestAuthorization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Hearing App")
        }
        .onAppear {
            checkAuthorization()
        }
    }

    private var statusText: String {
        switch dosePercent {
        case ..<50: return "Safe"
        case 50..<80: return "Moderate"
        case 80..<100: return "High"
        default: return "Dangerous"
        }
    }

    private var statusColor: Color {
        switch dosePercent {
        case ..<50: return .green
        case 50..<80: return .orange
        case 80..<100: return .orange
        default: return .red
        }
    }

    private func checkAuthorization() {
        // TODO: Check HealthKit authorization
    }

    private func requestAuthorization() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            isAuthorized = true
        } catch {
            print("Authorization failed: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
