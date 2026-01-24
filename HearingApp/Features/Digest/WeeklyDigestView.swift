import SwiftUI
import SwiftData

struct WeeklyDigestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var digest: WeeklyDigest?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if let digest = digest {
                    digestContent(digest)
                } else {
                    emptyState
                }
            }
        }
        .navigationTitle("Weekly Digest")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await loadDigest()
        }
    }

    // MARK: - Content

    private func digestContent(_ digest: WeeklyDigest) -> some View {
        VStack(spacing: 20) {
            // Header with date range
            headerSection(digest)
                .cardEntrance(delay: 0)

            // Main metric card
            mainMetricCard(digest)
                .cardEntrance(delay: 0.05)

            // Stats grid
            statsGrid(digest)
                .cardEntrance(delay: 0.1)

            // Loudest / Quietest days
            dayHighlights(digest)
                .cardEntrance(delay: 0.15)

            // Streak section
            streakSection(digest)
                .cardEntrance(delay: 0.2)
        }
        .padding()
    }

    private func headerSection(_ digest: WeeklyDigest) -> some View {
        VStack(spacing: 8) {
            Text(digest.dateRangeString)
                .font(AppTypography.title2)
                .foregroundColor(AppColors.label)

            if let change = digest.weekOverWeekChange {
                HStack(spacing: 4) {
                    Image(systemName: change > 0 ? "arrow.up.right" : (change < 0 ? "arrow.down.right" : "minus"))
                        .font(.system(size: 12, weight: .semibold))

                    Text(digest.comparisonIndicator)
                        .font(AppTypography.caption1)
                }
                .foregroundColor(change > 5 ? AppColors.danger : (change < -5 ? AppColors.safe : AppColors.secondaryLabel))
            }
        }
    }

    private func mainMetricCard(_ digest: WeeklyDigest) -> some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(spacing: 16) {
                // Average dose ring
                ZStack {
                    Circle()
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.05),
                            lineWidth: 12
                        )

                    Circle()
                        .trim(from: 0, to: min(digest.averageDosePercent / 100.0, 1.0))
                        .stroke(
                            AppColors.statusColor(for: digest.averageDosePercent),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(digest.averageDosePercent))%")
                            .font(AppTypography.dosePercentMedium)
                            .foregroundColor(AppColors.label)

                        Text("avg dose")
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .frame(width: 120, height: 120)

                // Week status
                StatusChipView(status: digest.weekStatus)

                // Comparison to previous week
                if let _ = digest.previousWeekAveragePercent,
                   let change = digest.weekOverWeekChange {
                    HStack(spacing: 8) {
                        Text("vs last week:")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.secondaryLabel)

                        HStack(spacing: 2) {
                            Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(abs(Int(change)))%")
                                .font(AppTypography.caption1)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(change > 0 ? AppColors.danger : AppColors.safe)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statsGrid(_ digest: WeeklyDigest) -> some View {
        SectionGlassCard(title: "Weekly Stats") {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                StatCardView(
                    title: "Total Listening",
                    value: digest.formattedTotalTime,
                    icon: "headphones",
                    color: AppColors.primaryFallback
                )

                StatCardView(
                    title: "Days Over Limit",
                    value: "\(digest.daysOverLimit)",
                    subtitle: "of \(digest.daysWithData) days",
                    icon: "exclamationmark.triangle",
                    color: digest.daysOverLimit > 0 ? AppColors.danger : AppColors.safe
                )

                if let avgLevel = digest.averageLevelDBASPL {
                    StatCardView(
                        title: "Avg Level",
                        value: "\(Int(avgLevel)) dB",
                        icon: "speaker.wave.2",
                        color: AppColors.statusColor(for: avgLevel < 85 ? 30 : (avgLevel < 90 ? 60 : 90))
                    )
                }

                StatCardView(
                    title: "Days Tracked",
                    value: "\(digest.daysWithData)",
                    subtitle: "this week",
                    icon: "calendar",
                    color: AppColors.primaryFallback
                )
            }
        }
    }

    private func dayHighlights(_ digest: WeeklyDigest) -> some View {
        SectionGlassCard(title: "Day Highlights") {
            VStack(spacing: 12) {
                if let loudestDate = digest.loudestDayDate,
                   let loudestDose = digest.loudestDayDosePercent {
                    dayHighlightRow(
                        title: "Loudest Day",
                        date: loudestDate,
                        dose: loudestDose,
                        icon: "speaker.wave.3.fill",
                        isLoudest: true
                    )
                }

                if let quietestDate = digest.quietestDayDate,
                   let quietestDose = digest.quietestDayDosePercent,
                   quietestDate != digest.loudestDayDate {
                    dayHighlightRow(
                        title: "Quietest Day",
                        date: quietestDate,
                        dose: quietestDose,
                        icon: "speaker.wave.1.fill",
                        isLoudest: false
                    )
                }
            }
        }
    }

    private func dayHighlightRow(
        title: String,
        date: Date,
        dose: Double,
        icon: String,
        isLoudest: Bool
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isLoudest ? AppColors.caution : AppColors.safe)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.label)

                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.secondaryLabel)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(dose))%")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.statusColor(for: dose))

                Text("dose")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.03)
                        : Color.black.opacity(0.02)
                )
        )
    }

    private func streakSection(_ digest: WeeklyDigest) -> some View {
        SectionGlassCard(title: "Safe Listening Streak") {
            HStack(spacing: 16) {
                // Current streak
                VStack(spacing: 8) {
                    Image(systemName: digest.currentStreak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 32))
                        .foregroundColor(digest.currentStreak > 0 ? AppColors.safe : AppColors.secondaryLabel)
                        .shadow(color: digest.currentStreak > 0 ? AppColors.safe.opacity(0.4) : .clear, radius: 6)

                    Text("\(digest.currentStreak)")
                        .font(AppTypography.title1)
                        .foregroundColor(AppColors.label)

                    Text("Current")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 60)

                // Best streak
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32))
                        .foregroundColor(digest.bestStreak > 0 ? Color.yellow : AppColors.secondaryLabel)

                    Text("\(digest.bestStreak)")
                        .font(AppTypography.title1)
                        .foregroundColor(AppColors.label)

                    Text("Best")
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var emptyState: some View {
        GlassCard(cornerRadius: 20, padding: 32) {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.secondaryLabel)

                Text("No Weekly Digest Yet")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.label)

                Text("Use the app for a full week to see your first weekly digest summary.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .padding(.top, 40)
    }

    // MARK: - Data Loading

    private func loadDigest() async {
        isLoading = true

        do {
            // Configure scheduler if needed
            WeeklyDigestScheduler.shared.configure(modelContext: modelContext)

            // Try to get existing digest
            if let existing = try WeeklyDigestScheduler.shared.getMostRecentDigest() {
                digest = existing
            } else {
                // Generate new digest
                digest = try await WeeklyDigestScheduler.shared.generateWeeklyDigest()
            }
        } catch {
            print("Error loading digest: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        WeeklyDigestView()
            .modelContainer(for: [WeeklyDigest.self, DailyDose.self])
    }
}
