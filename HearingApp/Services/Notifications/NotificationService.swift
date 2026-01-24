import Foundation
import UserNotifications

/// Service for managing local notifications
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized: Bool = false

    private let center = UNUserNotificationCenter.current()
    private var notificationCooldowns: [Int: Date] = [:]
    private let cooldownInterval: TimeInterval = 3600

    private init() {
        Task { await checkAuthorizationStatus() }
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func checkAndNotify(for dosePercent: Double) async {
        guard isAuthorized else { return }

        if dosePercent >= 100 {
            await sendThresholdNotification(threshold: 100, dosePercent: dosePercent)
        } else if dosePercent >= 80 {
            await sendThresholdNotification(threshold: 80, dosePercent: dosePercent)
        } else if dosePercent >= 50 {
            await sendThresholdNotification(threshold: 50, dosePercent: dosePercent)
        }
    }

    private func sendThresholdNotification(threshold: Int, dosePercent: Double) async {
        if let lastNotification = notificationCooldowns[threshold],
           Date().timeIntervalSince(lastNotification) < cooldownInterval {
            return
        }

        let content = UNMutableNotificationContent()

        switch threshold {
        case 100:
            content.title = "Daily Limit Reached"
            content.body = "You've used 100% of your daily sound allowance. Consider giving your ears a break."
            content.sound = .default
        case 80:
            content.title = "Approaching Limit"
            content.body = "You've used 80% of your daily sound allowance. Try lowering your volume."
            content.sound = .default
        case 50:
            content.title = "Halfway There"
            content.body = "You've used 50% of your daily sound allowance."
            content.sound = nil
        default:
            return
        }

        content.categoryIdentifier = "DOSE_THRESHOLD"
        content.threadIdentifier = "dose-alerts"

        let request = UNNotificationRequest(
            identifier: "dose-threshold-\(threshold)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            notificationCooldowns[threshold] = Date()
        } catch {
            print("Failed to send notification: \(error)")
        }
    }

    func registerCategories() {
        let viewAction = UNNotificationAction(identifier: "VIEW_ACTION", title: "View Details", options: [.foreground])
        let dismissAction = UNNotificationAction(identifier: "DISMISS_ACTION", title: "Dismiss", options: [])

        let doseCategory = UNNotificationCategory(
            identifier: "DOSE_THRESHOLD",
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([doseCategory])
    }
}
