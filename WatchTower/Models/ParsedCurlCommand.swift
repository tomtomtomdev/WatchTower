//
//  ParsedCurlCommand.swift
//  WatchTower
//

import Foundation

struct ParsedCurlCommand {
    var url: String
    var method: HTTPMethod
    var headers: [String: String]
    var body: String?

    init(url: String, method: HTTPMethod = .GET, headers: [String: String] = [:], body: String? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}
