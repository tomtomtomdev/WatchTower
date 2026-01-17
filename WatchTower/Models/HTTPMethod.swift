//
//  HTTPMethod.swift
//  WatchTower
//

import Foundation

enum HTTPMethod: String, Codable, CaseIterable, Identifiable {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
    case HEAD
    case OPTIONS

    var id: String { rawValue }
}
