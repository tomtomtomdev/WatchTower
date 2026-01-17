//
//  HealthCheckService.swift
//  WatchTower
//

import Foundation
import SwiftData
import Combine

@MainActor
class HealthCheckService: ObservableObject {
    private let networkService: NetworkService
    private let notificationService: NotificationService
    private let modelContext: ModelContext

    init(modelContext: ModelContext, networkService: NetworkService = NetworkService(), notificationService: NotificationService = .shared) {
        self.modelContext = modelContext
        self.networkService = networkService
        self.notificationService = notificationService
    }

    func performHealthCheck(for endpoint: APIEndpoint) async -> HealthCheckResult {
        let previousStatus = endpoint.currentStatus

        let response = await networkService.performRequest(
            url: endpoint.url,
            method: endpoint.method,
            headers: endpoint.headers,
            body: endpoint.body
        )

        let result = HealthCheckResult(
            endpoint: endpoint,
            timestamp: Date(),
            isSuccess: response.isSuccess,
            statusCode: response.statusCode,
            responseTime: response.responseTime,
            errorMessage: response.error?.localizedDescription
        )

        modelContext.insert(result)
        endpoint.lastCheckedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Failed to save health check result: \(error)")
        }

        await handleStatusTransition(
            endpoint: endpoint,
            previousStatus: previousStatus,
            newStatus: result.isSuccess ? .healthy : .failing,
            errorMessage: response.error?.localizedDescription ?? "Status code: \(response.statusCode ?? 0)"
        )

        return result
    }

    func performHealthCheckForAll(endpoints: [APIEndpoint]) async {
        await withTaskGroup(of: Void.self) { group in
            for endpoint in endpoints where endpoint.isEnabled {
                group.addTask { [weak self] in
                    _ = await self?.performHealthCheck(for: endpoint)
                }
            }
        }
    }

    private func handleStatusTransition(
        endpoint: APIEndpoint,
        previousStatus: EndpointStatus,
        newStatus: EndpointStatus,
        errorMessage: String
    ) async {
        if previousStatus == .healthy && newStatus == .failing {
            await notificationService.sendFailureNotification(
                endpointName: endpoint.name,
                errorMessage: errorMessage
            )
        } else if previousStatus == .failing && newStatus == .healthy {
            await notificationService.sendRecoveryNotification(endpointName: endpoint.name)
        }
    }
}
