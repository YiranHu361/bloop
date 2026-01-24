import SwiftUI
import SwiftData

/// Main dashboard view
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todaySamples: [ExposureSample]

    @State private var dosePercent: Double = 0
    @State private var averageDB: Double?
    @State private var peakDB: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Dose ring
                    DoseRingView(dosePercent: dosePercent)
                        .frame(width: 220, height: 220)
                        .padding(.top, 20)

                    // Status
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(statusColor)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Avg Level", value: averageDB.map { "\(Int($0)) dB" } ?? "--")
                        StatCard(title: "Peak Level", value: peakDB.map { "\(Int($0)) dB" } ?? "--")
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Today")
            .onAppear {
                calculateDose()
            }
        }
    }

    private var statusText: String {
        ExposureStatus.from(dosePercent: dosePercent).displayName
    }

    private var statusColor: Color {
        switch dosePercent {
        case ..<50: return .green
        case 50..<80: return .orange
        case 80..<100: return .orange
        default: return .red
        }
    }

    private func calculateDose() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaysSamples = todaySamples.filter { $0.startDate >= today }

        let calculator = DoseCalculator()
        let result = calculator.calculateDailyDose(from: todaysSamples)

        dosePercent = result.dosePercent
        averageDB = result.averageLevel
        peakDB = result.peakLevel
    }
}

struct DoseRingView: View {
    let dosePercent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 24)

            Circle()
                .trim(from: 0, to: min(dosePercent / 100, 1.0))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: dosePercent)

            VStack(spacing: 4) {
                Text("\(Int(dosePercent))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Text("Daily Dose")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var ringColor: Color {
        switch dosePercent {
        case ..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    TodayView()
}
