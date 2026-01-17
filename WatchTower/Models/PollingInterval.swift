//
//  PollingInterval.swift
//  WatchTower
//

import Foundation

enum PollingInterval: Int, Codable, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case hourly = 3600
    case biDaily = 43200
    case daily = 86400

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .fiveMinutes:
            return "5 minutes"
        case .fifteenMinutes:
            return "15 minutes"
        case .hourly:
            return "Hourly"
        case .biDaily:
            return "Every 12 hours"
        case .daily:
            return "Daily"
        }
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue)
    }
}
