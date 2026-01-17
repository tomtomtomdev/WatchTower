//
//  APIEndpoint.swift
//  WatchTower
//

import Foundation
import SwiftData

@Model
final class APIEndpoint {
    var id: UUID
    var name: String
    var url: String
    var method: HTTPMethod
    var headers: [String: String]
    var body: String?
    var pollingInterval: PollingInterval
    var isEnabled: Bool
    var lastCheckedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \HealthCheckResult.endpoint)
    var healthCheckResults: [HealthCheckResult] = []

    var currentStatus: EndpointStatus {
        guard let lastResult = healthCheckResults.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            return .unknown
        }
        return lastResult.isSuccess ? .healthy : .failing
    }

    var lastResponseTime: TimeInterval? {
        healthCheckResults.sorted(by: { $0.timestamp > $1.timestamp }).first?.responseTime
    }

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: String? = nil,
        pollingInterval: PollingInterval = .fifteenMinutes,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.pollingInterval = pollingInterval
        self.isEnabled = isEnabled
    }
}
