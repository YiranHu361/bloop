import SwiftUI

/// Detailed privacy information view for bloop.
/// Emphasizes: HealthKit-only, no mic, no content analysis
struct PrivacyDetailView: View {
    var body: some View {
        List {
            // Hero Section
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
                            Text("Privacy is Our Promise")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.label)
                            
                            Text("bloop. measures loudness, not listening")
                                .font(AppTypography.caption1)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // What We Access
            Section("What We Access") {
                dataAccessRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "HealthKit Headphone Audio",
                    description: "Volume levels only — not what your child listens to",
                    accessType: "Read Only"
                )
            }
            
            // Core Privacy Promise
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    privacyPromiseRow(
                        icon: "mic.slash.fill",
                        iconColor: AppColors.safe,
                        title: "No Microphone Access",
                        description: "bloop. never uses the microphone. We can't hear conversations, music, or any audio."
                    )
                    
                    Divider()
                    
                    privacyPromiseRow(
                        icon: "phone.down.fill",
                        iconColor: AppColors.safe,
                        title: "Phone Calls Stay Private",
                        description: "iOS doesn't allow apps to access call audio. Phone calls are completely private."
                    )
                    
                    Divider()
                    
                    privacyPromiseRow(
                        icon: "music.note",
                        iconColor: AppColors.safe,
                        title: "Content Stays Secret",
                        description: "We measure volume, not content. We never know what songs, videos, or apps are being used."
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Our Privacy Promise")
            } footer: {
                Text("bloop. protects kids' ears without spying, nagging, or interrupting.")
                    .font(AppTypography.caption1)
            }
            
            // What We DON'T Access
            Section("What We DON'T Access") {
                noAccessRow(icon: "mic.slash.fill", title: "Microphone", reason: "Never used — not even for features")
                noAccessRow(icon: "phone.down.fill", title: "Phone Calls", reason: "iOS prevents apps from accessing call audio")
                noAccessRow(icon: "music.note", title: "Audio Content", reason: "We only see volume levels, not what's playing")
                noAccessRow(icon: "text.bubble", title: "Messages", reason: "Not needed for hearing protection")
                noAccessRow(icon: "location.slash.fill", title: "Location", reason: "Not needed for this app")
                noAccessRow(icon: "camera.slash.fill", title: "Camera", reason: "Not needed for this app")
            }
            
            // Data Storage
            Section("Data Storage") {
                storageRow(
                    icon: "iphone",
                    title: "On-Device Only",
                    description: "All listening data stays on this device. Nothing is uploaded to servers."
                )
                
                storageRow(
                    icon: "trash",
                    title: "Parent Controls Deletion",
                    description: "Delete all data anytime from Settings → Data & Storage."
                )
                
                storageRow(
                    icon: "icloud.slash",
                    title: "No Cloud Sync",
                    description: "Data is not synced to iCloud or any external service."
                )
            }
            
            // Network Activity
            Section("Network Activity") {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.safe.opacity(0.12))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.safe)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Works Completely Offline")
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.label)
                        
                        Text("bloop. doesn't send data to servers, track usage, or collect analytics.")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Third-Party Services
            Section("Third-Party Services") {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.safe.opacity(0.12))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.safe)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Third-Party SDKs")
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.label)
                        
                        Text("Only Apple's native frameworks are used. No ads, no analytics, no tracking.")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Your Rights
            Section("Your Rights") {
                rightRow(title: "Access", description: "View all stored data in the app")
                rightRow(title: "Delete", description: "Remove all data at any time")
                rightRow(title: "Export", description: "Download your data in standard formats")
                rightRow(title: "Control", description: "Adjust alerts and monitoring level")
            }
            
            // Debug-only mic section
            #if DEBUG
            if FeatureFlags.micSpectrumEnabled {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("DEBUG: Mic Spectrum Enabled", systemImage: "ant.fill")
                            .font(AppTypography.caption1Bold)
                            .foregroundColor(AppColors.caution)
                        
                        Text("The spectrum visualization feature uses the microphone in Debug builds only. This is disabled in App Store releases.")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Developer Mode")
                }
            }
            #endif
        }
        .navigationTitle("Privacy Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Row Builders
    
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
    
    private func privacyPromiseRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.label)
                
                Text(description)
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
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
}

#Preview {
    NavigationStack {
        PrivacyDetailView()
    }
}
