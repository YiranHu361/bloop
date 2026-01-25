import SwiftUI
import HealthKit

/// Polished onboarding flow with privacy-first messaging
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var isRequestingPermissions = false
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            // Animated background
            MeshGradientBackground()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Skip") {
                            withAnimation {
                                currentPage = totalPages - 1
                            }
                        }
                        .font(AppTypography.buttonMedium)
                        .foregroundColor(AppColors.secondaryLabel)
                        .padding()
                    }
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    PrivacyFirstPage()
                        .tag(0)
                    
                    HowItWorksPage()
                        .tag(1)
                    
                    PermissionsPage(isRequesting: $isRequestingPermissions)
                        .tag(2)
                    
                    GetStartedPage {
                        appState.completeOnboarding()
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                
                // Progress indicators and navigation
                VStack(spacing: 24) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AppColors.primaryFallback : Color.white.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // Navigation button
                    if currentPage < totalPages - 1 {
                        Button(action: {
                            if currentPage == 2 && !isRequestingPermissions {
                                // Skip permissions page if already granted
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                        }) {
                            HStack {
                                Text(currentPage == 2 ? "Continue" : "Next")
                                    .font(AppTypography.buttonLarge)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.primaryFallback, AppColors.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: AppColors.primaryFallback.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 40)
                        .disabled(isRequestingPermissions)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Privacy First Page

struct PrivacyFirstPage: View {
    @State private var isAnimated = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Shield icon
            ZStack {
                Circle()
                    .fill(AppColors.safe.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(AppColors.safe)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            
            VStack(spacing: 16) {
                Text("Privacy First")
                    .font(AppTypography.title1)
                    .foregroundColor(.white)
                
                Text("We don't listen to what you're listening to")
                    .font(AppTypography.headline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 20) {
                privacyItem(icon: "mic.slash.fill", text: "No microphone access")
                privacyItem(icon: "waveform.slash", text: "No audio content analysis")
                privacyItem(icon: "iphone.and.arrow.forward", text: "All data stays on your device")
                privacyItem(icon: "chart.bar.xaxis", text: "No analytics or tracking")
            }
            .padding(.horizontal, 20)
            .offset(y: isAnimated ? 0 : 30)
            .opacity(isAnimated ? 1.0 : 0)
            
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAnimated = true
            }
        }
    }
    
    private func privacyItem(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.safe)
                .frame(width: 28)
            
            Text(text)
                .font(AppTypography.body)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// MARK: - How It Works Page

struct HowItWorksPage: View {
    @State private var isAnimated = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("How It Works")
                .font(AppTypography.title1)
                .foregroundColor(.white)
            
            VStack(spacing: 24) {
                howItWorksItem(
                    number: 1,
                    icon: "headphones",
                    title: "We read volume levels",
                    description: "From Apple's HealthKit when you use headphones"
                )
                
                howItWorksItem(
                    number: 2,
                    icon: "function",
                    title: "Calculate your dose",
                    description: "Using WHO-recommended safety formulas"
                )
                
                howItWorksItem(
                    number: 3,
                    icon: "bell.badge",
                    title: "Alert you before damage",
                    description: "Smart notifications help you stay safe"
                )
            }
            .padding(.horizontal, 16)
            .offset(y: isAnimated ? 0 : 30)
            .opacity(isAnimated ? 1.0 : 0)
            
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAnimated = true
            }
        }
    }
    
    private func howItWorksItem(number: Int, icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryFallback.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.primaryFallback)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

// MARK: - Permissions Page

struct PermissionsPage: View {
    @Binding var isRequesting: Bool
    @State private var healthKitStatus: PermissionStatus = .notDetermined
    @State private var notificationStatus: PermissionStatus = .notDetermined
    
    enum PermissionStatus {
        case notDetermined, granted, denied
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("Quick Setup")
                .font(AppTypography.title1)
                .foregroundColor(.white)
            
            Text("We need a couple of permissions to protect their hearing")
                .font(AppTypography.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                permissionCard(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "HealthKit Access",
                    description: "Read headphone audio levels",
                    status: healthKitStatus
                ) {
                    await requestHealthKit()
                }
                
                permissionCard(
                    icon: "bell.fill",
                    iconColor: AppColors.caution,
                    title: "Notifications",
                    description: "Alert you when approaching limits",
                    status: notificationStatus
                ) {
                    await requestNotifications()
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    private func permissionCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        status: PermissionStatus,
        action: @escaping () async -> Void
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(AppTypography.caption1)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            switch status {
            case .notDetermined:
                Button("Allow") {
                    Task {
                        isRequesting = true
                        await action()
                        isRequesting = false
                    }
                }
                .font(AppTypography.buttonSmall)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.primaryFallback)
                .clipShape(Capsule())
                
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.safe)
                
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.danger)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func requestHealthKit() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            withAnimation {
                healthKitStatus = .granted
            }
        } catch {
            withAnimation {
                healthKitStatus = .denied
            }
        }
    }
    
    private func requestNotifications() async {
        await NotificationService.shared.requestAuthorization()
        withAnimation {
            notificationStatus = NotificationService.shared.isAuthorized ? .granted : .denied
        }
    }
}

// MARK: - Get Started Page

struct GetStartedPage: View {
    let onComplete: () -> Void
    @State private var isAnimated = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Celebration icon
            ZStack {
                Circle()
                    .fill(AppColors.safe.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppColors.safe)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.5)
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(AppTypography.title1)
                    .foregroundColor(.white)
                
                Text("Start protecting their hearing today.\nWe'll help them stay within safe limits.")
                    .font(AppTypography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .offset(y: isAnimated ? 0 : 20)
            .opacity(isAnimated ? 1.0 : 0)
            
            Spacer()
            
            // Get Started button
            Button(action: onComplete) {
                HStack {
                    Text("Let's Go!")
                        .font(AppTypography.buttonLarge)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [AppColors.safe, Color(hex: "059669")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: AppColors.safe.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 40)
            .scaleEffect(isAnimated ? 1.0 : 0.9)
            .opacity(isAnimated ? 1.0 : 0)
            
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
