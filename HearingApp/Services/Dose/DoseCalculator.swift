import Foundation

/// Calculates noise dose based on NIOSH or OSHA standards
struct DoseCalculator {
    let model: DoseModel

    init(model: DoseModel = .niosh) {
        self.model = model
    }

    func calculateDailyDose(from samples: [ExposureSample]) -> DoseResult {
        guard !samples.isEmpty else { return DoseResult.empty }

        var totalDosePercent: Double = 0
        var totalExposureSeconds: Double = 0
        var weightedLevelSum: Double = 0
        var peakLevel: Double = 0
        var timeAbove85dB: Double = 0
        var timeAbove90dB: Double = 0

        for sample in samples {
            let duration = sample.duration
            let level = sample.levelDBASPL
            guard duration > 0 && level > 0 else { continue }

            let allowableSeconds = allowableTime(at: level)
            if allowableSeconds > 0 {
                let contribution = (duration / allowableSeconds) * 100.0
                totalDosePercent += contribution
            }

            totalExposureSeconds += duration
            weightedLevelSum += level * duration
            peakLevel = max(peakLevel, level)

            if level >= 85 { timeAbove85dB += duration }
            if level >= 90 { timeAbove90dB += duration }
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

    func allowableTime(at level: Double) -> TimeInterval {
        let referenceLevel = model.referenceLevel
        let exchangeRate = model.exchangeRate
        let referenceDuration = model.referenceDurationHours * 3600

        let exponent = (referenceLevel - level) / exchangeRate
        let allowableSeconds = referenceDuration * pow(2.0, exponent)
        return min(max(allowableSeconds, 1), 24 * 3600)
    }

    func remainingSafeTime(currentDosePercent: Double, at level: Double) -> TimeInterval {
        let remainingDosePercent = max(100 - currentDosePercent, 0)
        let allowableSeconds = allowableTime(at: level)
        return (remainingDosePercent / 100.0) * allowableSeconds
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        else if minutes > 0 { return "\(minutes) min" }
        else { return "< 1 min" }
    }
}

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
}
