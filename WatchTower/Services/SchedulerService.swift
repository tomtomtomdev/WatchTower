//
//  SchedulerService.swift
//  WatchTower
//

import Foundation
import SwiftData
import Combine

@MainActor
class SchedulerService: ObservableObject {
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var healthCheckService: HealthCheckService?
    private var modelContext: ModelContext?

    @Published private(set) var isRunning = false

    func configure(healthCheckService: HealthCheckService, modelContext: ModelContext) {
        self.healthCheckService = healthCheckService
        self.modelContext = modelContext
    }

    func startMonitoring(endpoints: [APIEndpoint]) {
        stopAllMonitoring()
        isRunning = true

        for endpoint in endpoints where endpoint.isEnabled {
            startMonitoring(endpoint: endpoint)
        }
    }

    func startMonitoring(endpoint: APIEndpoint) {
        guard endpoint.isEnabled else { return }

        tasks[endpoint.id]?.cancel()

        let task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, let healthCheckService = self.healthCheckService else { break }

                _ = await healthCheckService.performHealthCheck(for: endpoint)

                try? await Task.sleep(for: .seconds(endpoint.pollingInterval.timeInterval))
            }
        }

        tasks[endpoint.id] = task
    }

    func stopMonitoring(endpoint: APIEndpoint) {
        tasks[endpoint.id]?.cancel()
        tasks.removeValue(forKey: endpoint.id)
    }

    func stopAllMonitoring() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        isRunning = false
    }

    func restartMonitoring(endpoint: APIEndpoint) {
        stopMonitoring(endpoint: endpoint)
        if endpoint.isEnabled {
            startMonitoring(endpoint: endpoint)
        }
    }

    func triggerImmediateCheck(for endpoint: APIEndpoint) async {
        guard let healthCheckService = healthCheckService else { return }
        _ = await healthCheckService.performHealthCheck(for: endpoint)
    }

    deinit {
        for task in tasks.values {
            task.cancel()
        }
    }
}
