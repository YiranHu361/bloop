import Foundation

/// AI-generated insight about user's hearing exposure
struct AIInsight: Equatable {
    enum InsightType: Equatable {
        case safe                    // On track for a safe day
        case warning                 // Approaching limit
        case danger                  // Over or about to exceed limit
        case inactive                // Not currently listening
        case recovering              // Was high, now trending down
    }

    let type: InsightType
    let message: String
    let etaToLimit: TimeInterval?
    let estimatedLimitTime: Date?
    let burnRatePerHour: Double
    let isActivelyListening: Bool

    static let inactive = AIInsight(
        type: .inactive,
        message: "Start listening to see your hearing budget forecast.",
        etaToLimit: nil,
        estimatedLimitTime: nil,
        burnRatePerHour: 0,
        isActivelyListening: false
    )
}

/// Calculates noise dose based on exposure samples using NIOSH or OSHA standards
struct DoseCalculator {
    let model: DoseModel
    
    init(model: DoseModel = .niosh) {
        self.model = model
    }
    
    // MARK: - Core Calculation
    
    /// Calculate daily dose from exposure samples
    /// 
    /// Formula (NIOSH):
    /// - Reference: 85 dBA for 8 hours = 100% dose
    /// - Exchange rate: 3 dB (every 3 dB increase halves allowable time)
    /// - Allowable time at level L: T(L) = 8h × 2^((85-L)/3)
    /// - Dose contribution: (actual time / allowable time) × 100%
    func calculateDailyDose(from samples: [ExposureSample]) -> DoseResult {
        guard !samples.isEmpty else {
            return DoseResult.empty
        }
        
        var totalDosePercent: Double = 0
        var totalExposureSeconds: Double = 0
        var weightedLevelSum: Double = 0
        var peakLevel: Double = 0
        var timeAbove85dB: Double = 0
        var timeAbove90dB: Double = 0
        
        for sample in samples {
            let duration = sample.duration // seconds
            let level = sample.levelDBASPL
            
            // Skip very short or invalid samples
            guard duration > 0 && level > 0 else { continue }
            
            // Calculate allowable time at this level
            let allowableSeconds = allowableTime(at: level)
            
            // Calculate dose contribution
            if allowableSeconds > 0 {
                let contribution = (duration / allowableSeconds) * 100.0
                totalDosePercent += contribution
            }
            
            // Accumulate stats
            totalExposureSeconds += duration
            weightedLevelSum += level * duration
            peakLevel = max(peakLevel, level)
            
            if level >= 85 {
                timeAbove85dB += duration
            }
            if level >= 90 {
                timeAbove90dB += duration
            }
        }
        
        let averageLevel = totalExposureSeconds > 0 
            ? weightedLevelSum / totalExposureSeconds 
            : nil
        
        return DoseResult(
            dosePercent: totalDosePercent,
            totalExposureSeconds: totalExposureSeconds,
            averageLevel: averageLevel,
            peakLevel: peakLevel > 0 ? peakLevel : nil,
            timeAbove85dB: timeAbove85dB,
            timeAbove90dB: timeAbove90dB
        )
    }
    
    /// Calculate allowable time at a given dB level
    /// 
    /// NIOSH: T = 8 × 2^((85-L)/3) hours
    /// OSHA: T = 8 × 2^((90-L)/5) hours
    func allowableTime(at level: Double) -> TimeInterval {
        let referenceLevel = model.referenceLevel
        let exchangeRate = model.exchangeRate
        let referenceDuration = model.referenceDurationHours * 3600 // Convert to seconds
        
        // If level is below reference, allow more time
        // If level is above reference, allow less time
        let exponent = (referenceLevel - level) / exchangeRate
        let allowableHours = referenceDuration * pow(2.0, exponent)
        
        // Cap at reasonable limits (minimum 1 second, maximum 24 hours)
        return min(max(allowableHours, 1), 24 * 3600)
    }
    
    /// Calculate remaining safe listening time at a given level
    func remainingSafeTime(currentDosePercent: Double, at level: Double) -> TimeInterval {
        let remainingDosePercent = max(100 - currentDosePercent, 0)
        let allowableSeconds = allowableTime(at: level)
        
        // How much time at this level would use the remaining dose?
        // (time / allowable) × 100 = remainingDose
        // time = (remainingDose / 100) × allowable
        return (remainingDosePercent / 100.0) * allowableSeconds
    }
    
    /// Estimate level needed to stay under limit for remaining time
    func safeLevelForRemainingTime(
        currentDosePercent: Double,
        remainingListeningTime: TimeInterval
    ) -> Double {
        let remainingDosePercent = max(100 - currentDosePercent, 0)
        
        // We need: (remainingTime / allowable) × 100 <= remainingDose
        // So: allowable >= remainingTime × 100 / remainingDose
        let requiredAllowable = (remainingListeningTime * 100) / remainingDosePercent
        
        // Solve for level from allowable time formula
        // allowable = referenceDuration × 2^((referenceLevel - L) / exchangeRate)
        // requiredAllowable / referenceDuration = 2^((referenceLevel - L) / exchangeRate)
        // log2(requiredAllowable / referenceDuration) = (referenceLevel - L) / exchangeRate
        // L = referenceLevel - exchangeRate × log2(requiredAllowable / referenceDuration)
        
        let referenceDuration = model.referenceDurationHours * 3600
        let ratio = requiredAllowable / referenceDuration
        let safeLevel = model.referenceLevel - model.exchangeRate * log2(ratio)
        
        return max(safeLevel, 0)
    }
}

// MARK: - Result Types

struct DoseResult {
    let dosePercent: Double
    let totalExposureSeconds: Double
    let averageLevel: Double?
    let peakLevel: Double?
    let timeAbove85dB: Double
    let timeAbove90dB: Double
    
    static let empty = DoseResult(
        dosePercent: 0,
        totalExposureSeconds: 0,
        averageLevel: nil,
        peakLevel: nil,
        timeAbove85dB: 0,
        timeAbove90dB: 0
    )
    
    var status: ExposureStatus {
        ExposureStatus.from(dosePercent: dosePercent)
    }
    
    var formattedExposureTime: String {
        let hours = Int(totalExposureSeconds) / 3600
        let minutes = (Int(totalExposureSeconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - ETA & Burn Rate Calculations

extension DoseCalculator {
    /// Result containing burn rate analysis and ETA prediction
    struct BurnRateAnalysis {
        /// Current burn rate in dose percent per hour
        let burnRatePerHour: Double
        /// Estimated time until 100% dose is reached (nil if not actively listening or already over)
        let estimatedTimeToLimit: TimeInterval?
        /// Estimated time of day when limit will be reached (nil if not applicable)
        let estimatedLimitTime: Date?
        /// Whether the user is currently actively listening
        let isActivelyListening: Bool
        /// Comparison to typical burn rate (positive = faster than usual)
        let burnRateComparison: Double?

        static let inactive = BurnRateAnalysis(
            burnRatePerHour: 0,
            estimatedTimeToLimit: nil,
            estimatedLimitTime: nil,
            isActivelyListening: false,
            burnRateComparison: nil
        )
    }

    /// Analyze burn rate and estimate time to limit based on recent listening patterns
    /// - Parameters:
    ///   - currentDosePercent: Current accumulated dose percentage for the day
    ///   - recentSamples: Samples from a recent time window (e.g., last 30-60 minutes)
    ///   - windowMinutes: The time window in minutes that recentSamples covers
    ///   - typicalBurnRatePerHour: Optional typical burn rate for comparison
    /// - Returns: Analysis containing burn rate and ETA information
    func analyzeBurnRate(
        currentDosePercent: Double,
        recentSamples: [ExposureSample],
        windowMinutes: Double = 30,
        typicalBurnRatePerHour: Double? = nil
    ) -> BurnRateAnalysis {
        // Already at or over limit
        guard currentDosePercent < 100 else {
            return BurnRateAnalysis(
                burnRatePerHour: 0,
                estimatedTimeToLimit: 0,
                estimatedLimitTime: Date(),
                isActivelyListening: false,
                burnRateComparison: nil
            )
        }

        // Need samples to estimate burn rate
        guard !recentSamples.isEmpty else {
            return .inactive
        }

        // Calculate dose contribution from recent samples
        let recentDoseResult = calculateDailyDose(from: recentSamples)

        // If minimal dose in window, user isn't actively listening at risky levels
        // Threshold: less than 0.1% dose contribution in the window (lenient for testing)
        guard recentDoseResult.dosePercent > 0.1 else {
            return .inactive
        }

        // Calculate actual listening time in the window (not just window duration)
        let actualListeningSeconds = recentSamples.reduce(0.0) { $0 + $1.duration }

        // Need meaningful listening time to calculate rate
        guard actualListeningSeconds > 10 else { // At least 10 seconds of data (lenient for testing)
            return .inactive
        }

        // Calculate burn rate per hour based on actual listening time
        let listeningHours = actualListeningSeconds / 3600.0
        let burnRatePerHour = recentDoseResult.dosePercent / listeningHours

        // Remaining dose capacity
        let remainingDose = 100.0 - currentDosePercent

        // ETA in seconds (assuming continuous listening at current rate)
        let etaHours = remainingDose / burnRatePerHour
        let etaSeconds = etaHours * 3600.0

        // Cap at 24 hours - beyond that is not meaningful
        let cappedETA: TimeInterval? = etaSeconds <= 24 * 3600 ? etaSeconds : nil

        // Calculate estimated limit time
        let estimatedLimitTime: Date? = cappedETA.map { Date().addingTimeInterval($0) }

        // Compare to typical rate if provided
        let comparison: Double? = typicalBurnRatePerHour.map { typical in
            guard typical > 0 else { return 0 }
            return ((burnRatePerHour - typical) / typical) * 100.0
        }

        return BurnRateAnalysis(
            burnRatePerHour: burnRatePerHour,
            estimatedTimeToLimit: cappedETA,
            estimatedLimitTime: estimatedLimitTime,
            isActivelyListening: true,
            burnRateComparison: comparison
        )
    }

    /// Simple ETA calculation for backward compatibility
    /// - Parameters:
    ///   - currentDosePercent: Current accumulated dose percentage
    ///   - recentSamples: Samples from recent time window
    ///   - windowMinutes: Time window in minutes
    /// - Returns: Estimated seconds until 100% dose, or nil if not actively listening
    func estimateTimeToLimit(
        currentDosePercent: Double,
        recentSamples: [ExposureSample],
        windowMinutes: Double = 30
    ) -> TimeInterval? {
        let analysis = analyzeBurnRate(
            currentDosePercent: currentDosePercent,
            recentSamples: recentSamples,
            windowMinutes: windowMinutes
        )
        return analysis.estimatedTimeToLimit
    }

    /// Generate an AI insight based on current exposure data
    /// - Parameters:
    ///   - currentDosePercent: Current dose percentage for the day
    ///   - recentSamples: Recent exposure samples (last 30-60 min)
    ///   - typicalBurnRate: User's typical burn rate per hour (from personalization)
    /// - Returns: An AI insight with message and metadata
    func generateInsight(
        currentDosePercent: Double,
        recentSamples: [ExposureSample],
        typicalBurnRate: Double? = nil
    ) -> AIInsight {
        let analysis = analyzeBurnRate(
            currentDosePercent: currentDosePercent,
            recentSamples: recentSamples,
            windowMinutes: 30,
            typicalBurnRatePerHour: typicalBurnRate
        )

        // Not actively listening
        guard analysis.isActivelyListening else {
            if currentDosePercent >= 100 {
                return AIInsight(
                    type: .danger,
                    message: "You've exceeded today's safe listening limit. Give your ears a rest.",
                    etaToLimit: 0,
                    estimatedLimitTime: nil,
                    burnRatePerHour: 0,
                    isActivelyListening: false
                )
            } else if currentDosePercent >= 80 {
                return AIInsight(
                    type: .warning,
                    message: "You've used \(Int(currentDosePercent))% of your daily budget. Listen carefully if you continue.",
                    etaToLimit: nil,
                    estimatedLimitTime: nil,
                    burnRatePerHour: 0,
                    isActivelyListening: false
                )
            } else {
                return .inactive
            }
        }

        // Already over limit
        if currentDosePercent >= 100 {
            return AIInsight(
                type: .danger,
                message: "You're over today's limit. Consider giving your ears a break now.",
                etaToLimit: 0,
                estimatedLimitTime: Date(),
                burnRatePerHour: analysis.burnRatePerHour,
                isActivelyListening: true
            )
        }

        // Generate message based on ETA and burn rate
        let message = generateInsightMessage(
            currentDose: currentDosePercent,
            analysis: analysis
        )

        let insightType: AIInsight.InsightType
        if let eta = analysis.estimatedTimeToLimit {
            if eta < 30 * 60 { // Less than 30 minutes
                insightType = .danger
            } else if eta < 2 * 3600 || currentDosePercent >= 80 { // Less than 2 hours or high dose
                insightType = .warning
            } else {
                insightType = .safe
            }
        } else {
            insightType = currentDosePercent >= 80 ? .warning : .safe
        }

        return AIInsight(
            type: insightType,
            message: message,
            etaToLimit: analysis.estimatedTimeToLimit,
            estimatedLimitTime: analysis.estimatedLimitTime,
            burnRatePerHour: analysis.burnRatePerHour,
            isActivelyListening: true
        )
    }

    /// Generate a human-readable insight message
    private func generateInsightMessage(
        currentDose: Double,
        analysis: BurnRateAnalysis
    ) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        // Check if burning faster than typical
        let isFasterThanTypical = analysis.burnRateComparison.map { $0 > 20 } ?? false

        if let eta = analysis.estimatedTimeToLimit,
           let limitTime = analysis.estimatedLimitTime {

            let etaMinutes = Int(eta / 60)
            let etaHours = etaMinutes / 60
            let remainingMinutes = etaMinutes % 60

            // Format ETA string
            let etaString: String
            if etaHours > 0 {
                if remainingMinutes > 0 {
                    etaString = "\(etaHours)h \(remainingMinutes)m"
                } else {
                    etaString = "\(etaHours) hour\(etaHours > 1 ? "s" : "")"
                }
            } else {
                etaString = "\(etaMinutes) minute\(etaMinutes != 1 ? "s" : "")"
            }

            let timeString = timeFormatter.string(from: limitTime)

            // Critical: less than 30 minutes
            if etaMinutes < 30 {
                return "At this pace, you'll hit your limit in \(etaString). Consider lowering volume now."
            }

            // Warning: less than 2 hours
            if etaMinutes < 120 {
                if isFasterThanTypical {
                    return "You're listening louder than usual. At this rate, you'll reach your limit by \(timeString)."
                }
                return "At your current pace, you'll hit 100% by \(timeString). You have \(etaString) left."
            }

            // Safe: more than 2 hours remaining
            if currentDose < 30 {
                return "Looking good! At this pace, you have \(etaString) of safe listening remaining."
            } else if currentDose < 50 {
                return "You're on track. About \(etaString) of listening time left at current levels."
            } else {
                return "Budget at \(Int(currentDose))%. You have roughly \(etaString) remaining at this pace."
            }
        }

        // Fallback messages when ETA can't be calculated
        if currentDose < 30 {
            return "Your hearing is well protected. Keep enjoying your audio safely."
        } else if currentDose < 50 {
            return "Moderate usage so far. You're within safe listening levels."
        } else if currentDose < 80 {
            return "You've used \(Int(currentDose))% of your budget. Consider monitoring your volume."
        } else {
            return "Approaching your daily limit at \(Int(currentDose))%. Listen with care."
        }
    }
}

// MARK: - Convenience Extensions

extension DoseCalculator {
    /// Calculate weekly dose average
    func calculateWeeklyAverage(from dailyDoses: [DailyDose]) -> Double {
        guard !dailyDoses.isEmpty else { return 0 }
        let total = dailyDoses.reduce(0.0) { $0 + $1.dosePercent }
        return total / Double(dailyDoses.count)
    }
    
    /// Format time interval as human readable string
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }
    
    /// Get a human-readable description of a dB level
    static func levelDescription(_ level: Double) -> String {
        switch level {
        case ..<60:
            return "Quiet (normal conversation)"
        case 60..<70:
            return "Moderate (busy restaurant)"
        case 70..<80:
            return "Loud (vacuum cleaner)"
        case 80..<90:
            return "Very Loud (city traffic)"
        case 90..<100:
            return "Extremely Loud (lawn mower)"
        default:
            return "Dangerously Loud"
        }
    }
}
