//
//  EndpointStatus.swift
//  WatchTower
//

import Foundation
import SwiftUI

enum EndpointStatus: String, Codable {
    case healthy
    case failing
    case unknown
    case checking

    var color: Color {
        switch self {
        case .healthy:
            return .green
        case .failing:
            return .red
        case .unknown:
            return .gray
        case .checking:
            return .orange
        }
    }

    var iconName: String {
        switch self {
        case .healthy:
            return "checkmark.circle.fill"
        case .failing:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        case .checking:
            return "arrow.clockwise.circle.fill"
        }
    }
}
