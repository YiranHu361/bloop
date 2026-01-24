import SwiftUI

/// A circular progress ring showing daily sound allowance usage
struct DoseRingView: View {
    let dosePercent: Double
    let lineWidth: CGFloat
    let showLabel: Bool
    
    init(dosePercent: Double, lineWidth: CGFloat = 24, showLabel: Bool = true) {
        self.dosePercent = dosePercent
        self.lineWidth = lineWidth
        self.showLabel = showLabel
    }
    
    private var progress: Double {
        min(dosePercent / 100.0, 1.5) // Cap at 150% for visual
    }
    
    private var statusColor: Color {
        AppColors.statusColor(for: dosePercent)
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AppColors.ringBackground, lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    statusColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Overflow indicator (if > 100%)
            if dosePercent > 100 {
                Circle()
                    .trim(from: 0, to: (dosePercent - 100) / 100.0)
                    .stroke(
                        AppColors.danger.opacity(0.5),
                        style: StrokeStyle(lineWidth: lineWidth / 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: dosePercent)
            }
            
            // Center label
            if showLabel {
                VStack(spacing: 4) {
                    Text("\(Int(dosePercent))%")
                        .font(AppTypography.dosePercentLarge)
                        .foregroundColor(AppColors.label)
                    
                    Text("of daily limit")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        DoseRingView(dosePercent: 35)
            .frame(width: 200, height: 200)
        
        DoseRingView(dosePercent: 75)
            .frame(width: 200, height: 200)
        
        DoseRingView(dosePercent: 120)
            .frame(width: 200, height: 200)
    }
    .padding()
}
