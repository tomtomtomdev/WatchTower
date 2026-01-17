//
//  NotificationService.swift
//  WatchTower
//

import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var isAuthorized = false

    private let notificationCenter = UNUserNotificationCenter.current()

    override private init() {
        super.init()
        notificationCenter.delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }

    func requestAuthorization() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            print("Notification authorization failed: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func sendFailureNotification(endpointName: String, errorMessage: String) async {
        if !isAuthorized {
            await requestAuthorization()
        }
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "API Health Check Failed"
        content.body = "\(endpointName): \(errorMessage)"
        content.sound = .default
        content.categoryIdentifier = "HEALTH_CHECK_FAILURE"

        let request = UNNotificationRequest(
            identifier: "failure-\(endpointName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send notification: \(error.localizedDescription)")
        }
    }

    func sendRecoveryNotification(endpointName: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "API Recovered"
        content.body = "\(endpointName) is now healthy"
        content.sound = .default
        content.categoryIdentifier = "HEALTH_CHECK_RECOVERY"

        let request = UNNotificationRequest(
            identifier: "recovery-\(endpointName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send recovery notification: \(error.localizedDescription)")
        }
    }

    func setupNotificationCategories() {
        let checkNowAction = UNNotificationAction(
            identifier: "CHECK_NOW",
            title: "Check Now",
            options: .foreground
        )

        let viewDetailsAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: .foreground
        )

        let failureCategory = UNNotificationCategory(
            identifier: "HEALTH_CHECK_FAILURE",
            actions: [checkNowAction, viewDetailsAction],
            intentIdentifiers: [],
            options: []
        )

        let recoveryCategory = UNNotificationCategory(
            identifier: "HEALTH_CHECK_RECOVERY",
            actions: [viewDetailsAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([failureCategory, recoveryCategory])
    }
}

extension NotificationService: @preconcurrency UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "CHECK_NOW":
            NotificationCenter.default.post(name: .checkNowRequested, object: nil)
        case "VIEW_DETAILS":
            NotificationCenter.default.post(name: .viewDetailsRequested, object: nil)
        default:
            break
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let checkNowRequested = Notification.Name("checkNowRequested")
    static let viewDetailsRequested = Notification.Name("viewDetailsRequested")
}
