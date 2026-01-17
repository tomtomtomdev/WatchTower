//
//  HealthCheckResult.swift
//  WatchTower
//

import Foundation
import SwiftData

@Model
final class HealthCheckResult {
    var id: UUID
    var endpoint: APIEndpoint?
    var timestamp: Date
    var isSuccess: Bool
    var statusCode: Int?
    var responseTime: TimeInterval
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        endpoint: APIEndpoint? = nil,
        timestamp: Date = Date(),
        isSuccess: Bool,
        statusCode: Int? = nil,
        responseTime: TimeInterval,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.endpoint = endpoint
        self.timestamp = timestamp
        self.isSuccess = isSuccess
        self.statusCode = statusCode
        self.responseTime = responseTime
        self.errorMessage = errorMessage
    }
}
