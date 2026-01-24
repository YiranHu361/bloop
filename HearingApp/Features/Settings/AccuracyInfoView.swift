import SwiftUI

/// Information view explaining dose calculation accuracy
struct AccuracyInfoView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryFallback.opacity(0.12))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.primaryFallback)
                        }
                        
                        Text("How accurate is the dose calculation?")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.label)
                    }
                    
                    Text("Accuracy depends on your headphones and how Apple measures audio levels.")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.secondaryLabel)
                }
                .padding(.vertical, 8)
            }
            
            Section("Headphone Types") {
                accuracyRow(
                    icon: "airpodspro",
                    title: "AirPods Pro / Max",
                    accuracy: "Most Accurate",
                    color: AppColors.safe,
                    description: "Real-time measured levels with active noise cancellation compensation"
                )
                
                accuracyRow(
                    icon: "airpods",
                    title: "AirPods (2nd/3rd gen)",
                    accuracy: "Very Accurate",
                    color: AppColors.safe,
                    description: "Direct measurement from Apple's calibrated sensors"
                )
                
                accuracyRow(
                    icon: "beats.headphones",
                    title: "Beats Headphones",
                    accuracy: "Accurate",
                    color: AppColors.caution,
                    description: "Good accuracy with Apple's audio processing"
                )
                
                accuracyRow(
                    icon: "headphones",
                    title: "Other Headphones",
                    accuracy: "Estimated",
                    color: AppColors.warning,
                    description: "Based on volume level only - actual dB may vary"
                )
            }
            
            Section("Understanding the Numbers") {
                infoRow(
                    title: "dB (Decibels)",
                    description: "A logarithmic measure of sound intensity. Every 3 dB increase doubles the sound energy."
                )
                
                infoRow(
                    title: "Daily Dose",
                    description: "The percentage of your safe daily sound exposure used. 100% = WHO-recommended 8-hour limit at 85 dB."
                )
                
                infoRow(
                    title: "Exchange Rate",
                    description: "NIOSH uses 3 dB (doubles risk every 3 dB). OSHA uses 5 dB (more lenient for workplaces)."
                )
            }
            
            Section("Limitations") {
                VStack(alignment: .leading, spacing: 8) {
                    limitationItem("Volume estimation for non-Apple headphones may be ±5-10 dB off")
                    limitationItem("Bone conduction and hearing aids are not supported")
                    limitationItem("Speaker playback is not tracked")
                    limitationItem("Environmental noise is not measured (no microphone access)")
                }
                .padding(.vertical, 4)
            }
            
            Section("Tips for Best Accuracy") {
                tipRow(icon: "airpodspro", tip: "Use AirPods or Beats for most accurate tracking")
                tipRow(icon: "slider.horizontal.3", tip: "Calibrate volume: 50% volume ≈ 70-75 dB on most headphones")
                tipRow(icon: "clock", tip: "Check your dose throughout the day, not just at the end")
            }
        }
        .navigationTitle("Accuracy Info")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func accuracyRow(icon: String, title: String, accuracy: String, color: Color, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.secondaryLabel)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.label)
                    
                    Spacer()
                    
                    Text(accuracy)
                        .font(AppTypography.caption1Bold)
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text(description)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func infoRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.label)
            
            Text(description)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .padding(.vertical, 4)
    }
    
    private func limitationItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12))
                .foregroundColor(AppColors.caution)
                .padding(.top, 2)
            
            Text(text)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.secondaryLabel)
        }
    }
    
    private func tipRow(icon: String, tip: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.safe)
                .frame(width: 24)
            
            Text(tip)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.label)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AccuracyInfoView()
    }
}
