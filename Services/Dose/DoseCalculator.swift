import Foundation

/// Calculates noise dose based on NIOSH standards
struct DoseCalculator {
    /// Reference level (85 dB for NIOSH)
    let referenceLevel: Double = 85.0

    /// Exchange rate (3 dB for NIOSH)
    let exchangeRate: Double = 3.0

    /// Reference duration in hours
    let referenceDurationHours: Double = 8.0

    /// Calculate daily dose from exposure samples
    func calculateDailyDose(from samples: [ExposureSample]) -> DoseResult {
        guard !samples.isEmpty else {
            return DoseResult.empty
        }

        var totalDosePercent: Double = 0
        var totalExposureSeconds: Double = 0
        var weightedLevelSum: Double = 0
        var peakLevel: Double = 0

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
        }

        let averageLevel = totalExposureSeconds > 0
            ? weightedLevelSum / totalExposureSeconds
            : nil

        return DoseResult(
            dosePercent: totalDosePercent,
            totalExposureSeconds: totalExposureSeconds,
            averageLevel: averageLevel,
            peakLevel: peakLevel > 0 ? peakLevel : nil
        )
    }

    /// Calculate allowable time at a given dB level
    func allowableTime(at level: Double) -> TimeInterval {
        let referenceDuration = referenceDurationHours * 3600
        let exponent = (referenceLevel - level) / exchangeRate
        let allowableSeconds = referenceDuration * pow(2.0, exponent)
        return min(max(allowableSeconds, 1), 24 * 3600)
    }
}

struct DoseResult {
    let dosePercent: Double
    let totalExposureSeconds: Double
    let averageLevel: Double?
    let peakLevel: Double?

    static let empty = DoseResult(
        dosePercent: 0,
        totalExposureSeconds: 0,
        averageLevel: nil,
        peakLevel: nil
    )

    var status: ExposureStatus {
        ExposureStatus.from(dosePercent: dosePercent)
    }
}
