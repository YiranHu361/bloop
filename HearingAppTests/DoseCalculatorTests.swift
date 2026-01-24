import XCTest
@testable import HearingApp

final class DoseCalculatorTests: XCTestCase {
    
    // MARK: - NIOSH Model Tests
    
    func testNIOSH_AllowableTimeAt85dB() {
        let calculator = DoseCalculator(model: .niosh)
        
        // At 85 dB, allowable time should be 8 hours
        let allowable = calculator.allowableTime(at: 85)
        let expectedSeconds = 8 * 3600.0
        
        XCTAssertEqual(allowable, expectedSeconds, accuracy: 1.0)
    }
    
    func testNIOSH_AllowableTimeAt88dB() {
        let calculator = DoseCalculator(model: .niosh)
        
        // At 88 dB (+3 dB), allowable time should be 4 hours
        let allowable = calculator.allowableTime(at: 88)
        let expectedSeconds = 4 * 3600.0
        
        XCTAssertEqual(allowable, expectedSeconds, accuracy: 1.0)
    }
    
    func testNIOSH_AllowableTimeAt91dB() {
        let calculator = DoseCalculator(model: .niosh)
        
        // At 91 dB (+6 dB), allowable time should be 2 hours
        let allowable = calculator.allowableTime(at: 91)
        let expectedSeconds = 2 * 3600.0
        
        XCTAssertEqual(allowable, expectedSeconds, accuracy: 1.0)
    }
    
    func testNIOSH_AllowableTimeAt82dB() {
        let calculator = DoseCalculator(model: .niosh)
        
        // At 82 dB (-3 dB), allowable time should be 16 hours
        let allowable = calculator.allowableTime(at: 82)
        let expectedSeconds = 16 * 3600.0
        
        XCTAssertEqual(allowable, expectedSeconds, accuracy: 1.0)
    }
    
    // MARK: - OSHA Model Tests
    
    func testOSHA_AllowableTimeAt90dB() {
        let calculator = DoseCalculator(model: .osha)
        
        // At 90 dB, allowable time should be 8 hours
        let allowable = calculator.allowableTime(at: 90)
        let expectedSeconds = 8 * 3600.0
        
        XCTAssertEqual(allowable, expectedSeconds, accuracy: 1.0)
    }
    
    func testOSHA_AllowableTimeAt95dB() {
        let calculator = DoseCalculator(model: .osha)
        
        // At 95 dB (+5 dB), allowable time should be 4 hours
        let allowable = calculator.allowableTime(at: 95)
        let expectedSeconds = 4 * 3600.0
        
        XCTAssertEqual(allowable, expectedSeconds, accuracy: 1.0)
    }
    
    // MARK: - Dose Calculation Tests
    
    func testEmptySamples_ReturnsZeroDose() {
        let calculator = DoseCalculator(model: .niosh)
        let result = calculator.calculateDailyDose(from: [])
        
        XCTAssertEqual(result.dosePercent, 0)
        XCTAssertEqual(result.totalExposureSeconds, 0)
        XCTAssertNil(result.averageLevel)
    }
    
    func testSingleSample_At85dB_For8Hours() {
        let calculator = DoseCalculator(model: .niosh)
        
        let start = Date()
        let end = start.addingTimeInterval(8 * 3600)
        
        let sample = ExposureSample(
            startDate: start,
            endDate: end,
            levelDBASPL: 85.0
        )
        
        let result = calculator.calculateDailyDose(from: [sample])
        
        // 8 hours at 85 dB should be exactly 100% dose
        XCTAssertEqual(result.dosePercent, 100, accuracy: 0.1)
        XCTAssertEqual(result.totalExposureSeconds, 8 * 3600, accuracy: 1.0)
        XCTAssertEqual(result.averageLevel ?? 0, 85, accuracy: 0.1)
    }
    
    func testSingleSample_At88dB_For4Hours() {
        let calculator = DoseCalculator(model: .niosh)
        
        let start = Date()
        let end = start.addingTimeInterval(4 * 3600)
        
        let sample = ExposureSample(
            startDate: start,
            endDate: end,
            levelDBASPL: 88.0
        )
        
        let result = calculator.calculateDailyDose(from: [sample])
        
        // 4 hours at 88 dB should be exactly 100% dose
        XCTAssertEqual(result.dosePercent, 100, accuracy: 0.1)
    }
    
    func testMultipleSamples_AccumulatesDose() {
        let calculator = DoseCalculator(model: .niosh)
        
        let start1 = Date()
        let end1 = start1.addingTimeInterval(2 * 3600) // 2 hours
        
        let start2 = end1
        let end2 = start2.addingTimeInterval(2 * 3600) // 2 hours
        
        let sample1 = ExposureSample(
            startDate: start1,
            endDate: end1,
            levelDBASPL: 85.0
        )
        
        let sample2 = ExposureSample(
            startDate: start2,
            endDate: end2,
            levelDBASPL: 88.0
        )
        
        let result = calculator.calculateDailyDose(from: [sample1, sample2])
        
        // 2 hours at 85 dB = 25% + 2 hours at 88 dB = 50% = 75% total
        XCTAssertEqual(result.dosePercent, 75, accuracy: 1.0)
        XCTAssertEqual(result.totalExposureSeconds, 4 * 3600, accuracy: 1.0)
    }
    
    func testTimeAboveThresholds() {
        let calculator = DoseCalculator(model: .niosh)
        
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour
        
        let sample = ExposureSample(
            startDate: start,
            endDate: end,
            levelDBASPL: 92.0
        )
        
        let result = calculator.calculateDailyDose(from: [sample])
        
        XCTAssertEqual(result.timeAbove85dB, 3600, accuracy: 1.0)
        XCTAssertEqual(result.timeAbove90dB, 3600, accuracy: 1.0)
    }
    
    func testTimeAbove85Only() {
        let calculator = DoseCalculator(model: .niosh)
        
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour
        
        let sample = ExposureSample(
            startDate: start,
            endDate: end,
            levelDBASPL: 87.0
        )
        
        let result = calculator.calculateDailyDose(from: [sample])
        
        XCTAssertEqual(result.timeAbove85dB, 3600, accuracy: 1.0)
        XCTAssertEqual(result.timeAbove90dB, 0, accuracy: 1.0)
    }
    
    func testPeakLevelTracking() {
        let calculator = DoseCalculator(model: .niosh)
        
        let start = Date()
        
        let samples = [
            ExposureSample(
                startDate: start,
                endDate: start.addingTimeInterval(1800),
                levelDBASPL: 75.0
            ),
            ExposureSample(
                startDate: start.addingTimeInterval(1800),
                endDate: start.addingTimeInterval(3600),
                levelDBASPL: 95.0
            ),
            ExposureSample(
                startDate: start.addingTimeInterval(3600),
                endDate: start.addingTimeInterval(5400),
                levelDBASPL: 80.0
            )
        ]
        
        let result = calculator.calculateDailyDose(from: samples)
        
        XCTAssertEqual(result.peakLevel ?? 0, 95, accuracy: 0.1)
    }
    
    // MARK: - Remaining Time Tests
    
    func testRemainingSafeTime_At50PercentDose() {
        let calculator = DoseCalculator(model: .niosh)
        
        // At 50% dose, 85 dB level, should have 4 more hours
        let remaining = calculator.remainingSafeTime(currentDosePercent: 50, at: 85)
        let expectedSeconds = 4 * 3600.0
        
        XCTAssertEqual(remaining, expectedSeconds, accuracy: 60.0) // Allow 1 minute tolerance
    }
    
    func testRemainingSafeTime_At100PercentDose() {
        let calculator = DoseCalculator(model: .niosh)
        
        // At 100% dose, should have 0 remaining time
        let remaining = calculator.remainingSafeTime(currentDosePercent: 100, at: 85)
        
        XCTAssertEqual(remaining, 0, accuracy: 1.0)
    }
    
    // MARK: - Status Tests
    
    func testStatus_Safe() {
        let result = DoseResult(
            dosePercent: 30,
            totalExposureSeconds: 3600,
            averageLevel: 75,
            peakLevel: 80,
            timeAbove85dB: 0,
            timeAbove90dB: 0
        )
        
        XCTAssertEqual(result.status, .safe)
    }
    
    func testStatus_Caution() {
        let result = DoseResult(
            dosePercent: 65,
            totalExposureSeconds: 7200,
            averageLevel: 85,
            peakLevel: 88,
            timeAbove85dB: 3600,
            timeAbove90dB: 0
        )
        
        XCTAssertEqual(result.status, .caution)
    }
    
    func testStatus_Danger() {
        let result = DoseResult(
            dosePercent: 110,
            totalExposureSeconds: 14400,
            averageLevel: 90,
            peakLevel: 95,
            timeAbove85dB: 14400,
            timeAbove90dB: 7200
        )

        XCTAssertEqual(result.status, .danger)
    }

    // MARK: - ETA & Burn Rate Tests

    func testBurnRateAnalysis_ActiveListening() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        // Create samples for last 30 minutes at 85 dB (should burn 6.25% per 30 min = 12.5% per hour)
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now.addingTimeInterval(-15 * 60),
                levelDBASPL: 85.0
            ),
            ExposureSample(
                startDate: now.addingTimeInterval(-15 * 60),
                endDate: now,
                levelDBASPL: 85.0
            )
        ]

        let analysis = calculator.analyzeBurnRate(
            currentDosePercent: 25,
            recentSamples: samples,
            windowMinutes: 30
        )

        XCTAssertTrue(analysis.isActivelyListening)
        // Burn rate should be approximately 12.5% per hour at 85 dB
        XCTAssertEqual(analysis.burnRatePerHour, 12.5, accuracy: 0.5)
        // ETA should be approximately 6 hours (75% remaining / 12.5% per hour)
        XCTAssertNotNil(analysis.estimatedTimeToLimit)
        if let eta = analysis.estimatedTimeToLimit {
            let etaHours = eta / 3600.0
            XCTAssertEqual(etaHours, 6.0, accuracy: 0.5)
        }
    }

    func testBurnRateAnalysis_NoSamples() {
        let calculator = DoseCalculator(model: .niosh)

        let analysis = calculator.analyzeBurnRate(
            currentDosePercent: 50,
            recentSamples: [],
            windowMinutes: 30
        )

        XCTAssertFalse(analysis.isActivelyListening)
        XCTAssertNil(analysis.estimatedTimeToLimit)
        XCTAssertEqual(analysis.burnRatePerHour, 0)
    }

    func testBurnRateAnalysis_AlreadyOverLimit() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now,
                levelDBASPL: 90.0
            )
        ]

        let analysis = calculator.analyzeBurnRate(
            currentDosePercent: 110,
            recentSamples: samples,
            windowMinutes: 30
        )

        // When over limit, ETA should be 0
        XCTAssertEqual(analysis.estimatedTimeToLimit, 0)
    }

    func testEstimateTimeToLimit_Simple() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        // 30 minutes at 88 dB = 12.5% dose (4 hours allowable, 0.5 hours = 12.5%)
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now,
                levelDBASPL: 88.0
            )
        ]

        let eta = calculator.estimateTimeToLimit(
            currentDosePercent: 50,
            recentSamples: samples,
            windowMinutes: 30
        )

        XCTAssertNotNil(eta)
        // At 25% per hour burn rate, 50% remaining = 2 hours = 7200 seconds
        if let eta = eta {
            XCTAssertEqual(eta, 2 * 3600, accuracy: 600) // Allow 10 minute tolerance
        }
    }

    func testEstimateTimeToLimit_LowDoseSamples() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        // Very low level listening should return nil (not actively listening at risky levels)
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now,
                levelDBASPL: 60.0 // Very low level
            )
        ]

        let eta = calculator.estimateTimeToLimit(
            currentDosePercent: 20,
            recentSamples: samples,
            windowMinutes: 30
        )

        // Low dose contribution should result in nil (not actively listening at risky levels)
        // or a very large ETA
        if let eta = eta {
            // If there is an ETA, it should be very large (many hours)
            XCTAssertGreaterThan(eta, 20 * 3600) // More than 20 hours
        }
    }

    // MARK: - AI Insight Generation Tests

    func testGenerateInsight_SafeState() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now,
                levelDBASPL: 80.0 // Moderate level
            )
        ]

        let insight = calculator.generateInsight(
            currentDosePercent: 20,
            recentSamples: samples
        )

        XCTAssertEqual(insight.type, .safe)
        XCTAssertTrue(insight.isActivelyListening)
        XCTAssertFalse(insight.message.isEmpty)
    }

    func testGenerateInsight_WarningState() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now,
                levelDBASPL: 88.0
            )
        ]

        let insight = calculator.generateInsight(
            currentDosePercent: 75,
            recentSamples: samples
        )

        // Should be warning because dose is high and ETA is limited
        XCTAssertTrue(insight.type == .warning || insight.type == .danger)
        XCTAssertTrue(insight.isActivelyListening)
    }

    func testGenerateInsight_DangerState() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now,
                levelDBASPL: 95.0 // Very loud
            )
        ]

        let insight = calculator.generateInsight(
            currentDosePercent: 95,
            recentSamples: samples
        )

        XCTAssertEqual(insight.type, .danger)
    }

    func testGenerateInsight_OverLimit() {
        let calculator = DoseCalculator(model: .niosh)

        let now = Date()
        let samples = [
            ExposureSample(
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now,
                levelDBASPL: 90.0
            )
        ]

        let insight = calculator.generateInsight(
            currentDosePercent: 110,
            recentSamples: samples
        )

        XCTAssertEqual(insight.type, .danger)
        XCTAssertTrue(insight.message.contains("over") || insight.message.contains("exceeded") || insight.message.contains("limit"))
    }

    func testGenerateInsight_Inactive() {
        let calculator = DoseCalculator(model: .niosh)

        let insight = calculator.generateInsight(
            currentDosePercent: 30,
            recentSamples: []
        )

        XCTAssertEqual(insight.type, .inactive)
        XCTAssertFalse(insight.isActivelyListening)
    }
}
