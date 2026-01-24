import SwiftUI

/// Polished onboarding flow with privacy-first messaging
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var isRequestingPermissions = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Skip") {
                            withAnimation { currentPage = totalPages - 1 }
                        }
                        .font(AppTypography.buttonMedium)
                        .foregroundColor(.white.opacity(0.7))
                        .padding()
                    }
                }

                TabView(selection: $currentPage) {
                    WelcomePage().tag(0)
                    PrivacyFirstPage().tag(1)
                    HowItWorksPage().tag(2)
                    PermissionsPage(isRequesting: $isRequestingPermissions).tag(3)
                    GetStartedPage { appState.completeOnboarding() }.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)

                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AppColors.primaryFallback : Color.white.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    if currentPage < totalPages - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            HStack {
                                Text("Next")
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

struct WelcomePage: View {
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primaryFallback, AppColors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: AppColors.primaryFallback.opacity(0.4), radius: 20, x: 0, y: 10)

                Image(systemName: "ear.and.waveform")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0)

            VStack(spacing: 16) {
                Text("SafeSound")
                    .font(AppTypography.largeTitle)
                    .foregroundColor(.white)

                Text("Protect your hearing.\nPrivately. Intelligently.")
                    .font(AppTypography.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .offset(y: isAnimated ? 0 : 20)
            .opacity(isAnimated ? 1.0 : 0)

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                isAnimated = true
            }
        }
    }
}

struct PrivacyFirstPage: View {
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

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

struct HowItWorksPage: View {
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("How It Works")
                .font(AppTypography.title1)
                .foregroundColor(.white)

            VStack(spacing: 24) {
                howItWorksItem(icon: "headphones", title: "We read volume levels", description: "From Apple's HealthKit when you use headphones")
                howItWorksItem(icon: "function", title: "Calculate your dose", description: "Using WHO-recommended safety formulas")
                howItWorksItem(icon: "bell.badge", title: "Alert you before damage", description: "Smart notifications help you stay safe")
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

    private func howItWorksItem(icon: String, title: String, description: String) -> some View {
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

struct PermissionsPage: View {
    @Binding var isRequesting: Bool
    @State private var healthKitGranted = false
    @State private var notificationGranted = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Quick Setup")
                .font(AppTypography.title1)
                .foregroundColor(.white)

            Text("We need a couple of permissions to protect your hearing")
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
                    isGranted: healthKitGranted
                ) {
                    await requestHealthKit()
                }

                permissionCard(
                    icon: "bell.fill",
                    iconColor: AppColors.caution,
                    title: "Notifications",
                    description: "Alert you when approaching limits",
                    isGranted: notificationGranted
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

    private func permissionCard(icon: String, iconColor: Color, title: String, description: String, isGranted: Bool, action: @escaping () async -> Void) -> some View {
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

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.safe)
            } else {
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
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func requestHealthKit() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            withAnimation { healthKitGranted = true }
        } catch {
            print("HealthKit error: \(error)")
        }
    }

    private func requestNotifications() async {
        await NotificationService.shared.requestAuthorization()
        withAnimation { notificationGranted = NotificationService.shared.isAuthorized }
    }
}

struct GetStartedPage: View {
    let onComplete: () -> Void
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

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

                Text("Start protecting your hearing today.\nWe'll help you stay within safe limits.")
                    .font(AppTypography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .offset(y: isAnimated ? 0 : 20)
            .opacity(isAnimated ? 1.0 : 0)

            Spacer()

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

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
