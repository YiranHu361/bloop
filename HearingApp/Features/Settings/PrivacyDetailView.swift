import SwiftUI

/// Detailed privacy information view
struct PrivacyDetailView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.safe.opacity(0.12))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.safe)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Privacy is Protected")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.label)
                            
                            Text("SafeSound is designed with privacy at its core")
                                .font(AppTypography.caption1)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("What We Access") {
                dataAccessRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "HealthKit Audio Levels",
                    description: "Volume levels from your headphones (not audio content)",
                    accessType: "Read Only"
                )

                dataAccessRow(
                    icon: "sparkles",
                    iconColor: AppColors.primaryFallback,
                    title: "AI Insights (Gemini)",
                    description: "Personalized hearing advice powered by AI",
                    accessType: "Optional"
                )
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.safe.opacity(0.12))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.safe)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phone Calls Are Private")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.label)
                            
                            Text("iOS does not allow apps to access phone call audio. Your calls are completely private.")
                                .font(AppTypography.caption1)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Important")
            }
            
            Section("What We DON'T Access") {
                noAccessRow(icon: "phone.down.fill", title: "Phone Calls", reason: "iOS prevents apps from accessing call audio")
                noAccessRow(icon: "music.note", title: "Audio Content", reason: "We don't know what you're listening to")
                noAccessRow(icon: "record.circle", title: "Audio Recording", reason: "We never record or store any audio")
                noAccessRow(icon: "location.slash.fill", title: "Location", reason: "Not needed for hearing protection")
                noAccessRow(icon: "person.crop.circle.badge.xmark", title: "Contacts", reason: "This is a personal health app")
                noAccessRow(icon: "camera.slash.fill", title: "Camera", reason: "Not needed for this app")
            }
            
            Section("Data Storage") {
                storageRow(
                    icon: "iphone",
                    title: "On-Device Only",
                    description: "All your listening data is stored locally on your device and never leaves it."
                )
                
                storageRow(
                    icon: "trash",
                    title: "You Control Deletion",
                    description: "You can delete all data at any time from Settings → Data & Storage."
                )
                
                storageRow(
                    icon: "icloud.slash",
                    title: "No Cloud Sync",
                    description: "Your data is not synced to iCloud or any external servers."
                )
            }
            
            Section("Network Activity") {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primaryFallback.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.primaryFallback)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Insights Only")
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.label)

                        Text("Network is only used for AI-powered insights via Gemini. Only anonymized dose data (percentages) is sent - never personal information or listening history.")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Third-Party Services") {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.safe.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.safe)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Google Gemini AI")
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.label)

                        Text("Powers personalized hearing advice. Only anonymous dose percentages are shared - no personal data, audio, or listening history.")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Your Rights") {
                rightRow(title: "Access", description: "View all your stored data in the app")
                rightRow(title: "Delete", description: "Remove all data at any time")
                rightRow(title: "Export", description: "Download your data in standard formats")
                rightRow(title: "Control", description: "Choose what level of monitoring you want")
            }
        }
        .navigationTitle("Privacy Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func dataAccessRow(icon: String, iconColor: Color, title: String, description: String, accessType: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.label)
                
                Text(description)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
            
            Spacer()
            
            Text(accessType)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.primaryFallback)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primaryFallback.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    private func noAccessRow(icon: String, title: String, reason: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.safe)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.label)
                
                Text(reason)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
            
            Spacer()
            
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.safe)
        }
        .padding(.vertical, 2)
    }
    
    private func storageRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.primaryFallback)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.label)
                
                Text(description)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func rightRow(title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.safe)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.label)
                
                Text(description)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func privacyBullet(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.safe)
                .padding(.top, 2)
            
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.label)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyDetailView()
    }
}
