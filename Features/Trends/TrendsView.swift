import SwiftUI
import SwiftData

/// Basic trends view
struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyDose.date, order: .reverse) private var dailyDoses: [DailyDose]

    var body: some View {
        NavigationStack {
            List {
                if dailyDoses.isEmpty {
                    Text("No data yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(dailyDoses, id: \.date) { dose in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(formatDate(dose.date))
                                    .font(.headline)

                                Text("\(Int(dose.totalExposureSeconds / 60)) min exposure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(Int(dose.dosePercent))%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colorFor(dose.dosePercent))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Trends")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func colorFor(_ percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}

#Preview {
    TrendsView()
}
