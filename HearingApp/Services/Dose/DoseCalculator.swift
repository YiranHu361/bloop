import Foundation

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
