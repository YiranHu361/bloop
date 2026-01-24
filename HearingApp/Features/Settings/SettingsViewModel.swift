import Foundation
import SwiftUI
import SwiftData

/// ViewModel for Settings view
@MainActor
final class SettingsViewModel: ObservableObject {
    // Monitoring
    @Published var monitoringMode: MonitoringMode = .full
    
    // Notifications
    @Published var notify50Percent: Bool = true
    @Published var notify75Percent: Bool = true
    @Published var notify100Percent: Bool = true
    
    // Dose model
    @Published var doseModel: DoseModel = .niosh
    
    // Data storage
    @Published var historyDuration: Int = 30 // days, 0 = forever
    
    private var modelContext: ModelContext?
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSettings()
    }
    
    private func loadSettings() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(descriptor)
            
            if let userSettings = settings.first {
                doseModel = userSettings.doseModelEnum
                notify50Percent = userSettings.warningThreshold50Enabled
                notify75Percent = userSettings.warningThreshold80Enabled // Using 80 for 75
                notify100Percent = userSettings.warningThreshold100Enabled
            }
        } catch {
            print("Error loading settings: \(error)")
        }
    }
    
    func saveSettings() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserSettings>()
            let settings = try context.fetch(descriptor)
            
            if let userSettings = settings.first {
                userSettings.doseModel = doseModel.rawValue
                userSettings.warningThreshold50Enabled = notify50Percent
                userSettings.warningThreshold80Enabled = notify75Percent
                userSettings.warningThreshold100Enabled = notify100Percent
                userSettings.lastModified = Date()
            } else {
                let newSettings = UserSettings(
                    doseModel: doseModel,
                    warningThreshold50Enabled: notify50Percent,
                    warningThreshold80Enabled: notify75Percent,
                    warningThreshold100Enabled: notify100Percent
                )
                context.insert(newSettings)
            }
            
            try context.save()
        } catch {
            print("Error saving settings: \(error)")
        }
    }
    
    // MARK: - Debug Functions
    
    func generateSampleData(context: ModelContext) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Generate 14 days of sample data
        for daysAgo in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            
            // Random dose between 20-120%
            let dosePercent = Double.random(in: 20...120)
            let avgLevel = Double.random(in: 65...95)
            let peakLevel = avgLevel + Double.random(in: 5...15)
            let exposureTime = Double.random(in: 1800...14400) // 30 min to 4 hours
            
            let dose = DailyDose(
                date: date,
                dosePercent: dosePercent,
                totalExposureSeconds: exposureTime,
                averageLevelDBASPL: avgLevel,
                peakLevelDBASPL: peakLevel,
                timeAbove85dB: dosePercent > 50 ? exposureTime * 0.3 : 0,
                timeAbove90dB: dosePercent > 80 ? exposureTime * 0.1 : 0
            )
            
            context.insert(dose)
        }
        
        // Generate some exposure samples for today
        for hourAgo in 0..<8 {
            guard let startTime = calendar.date(byAdding: .hour, value: -hourAgo, to: Date()),
                  let endTime = calendar.date(byAdding: .minute, value: 30, to: startTime) else { continue }
            
            let sample = ExposureSample(
                healthKitUUID: "debug-sample-\(UUID().uuidString)",
                startDate: startTime,
                endDate: endTime,
                levelDBASPL: Double.random(in: 60...95)
            )
            context.insert(sample)
        }
        
        try? context.save()
    }
    
    func clearAllData(context: ModelContext) async {
        do {
            try context.delete(model: DailyDose.self)
            try context.delete(model: ExposureSample.self)
            try context.delete(model: ExposureEvent.self)
            try context.delete(model: SyncState.self)
            try context.save()
        } catch {
            print("Error clearing data: \(error)")
        }
    }
}
