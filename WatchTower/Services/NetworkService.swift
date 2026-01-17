//
//  NetworkService.swift
//  WatchTower
//

import Foundation

struct NetworkResponse {
    let statusCode: Int?
    let responseTime: TimeInterval
    let data: Data?
    let error: Error?

    var isSuccess: Bool {
        guard let statusCode = statusCode else { return false }
        return (200..<300).contains(statusCode)
    }
}

actor NetworkService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func performRequest(
        url: String,
        method: HTTPMethod,
        headers: [String: String],
        body: String?
    ) async -> NetworkResponse {
        guard let requestURL = URL(string: url) else {
            return NetworkResponse(
                statusCode: nil,
                responseTime: 0,
                data: nil,
                error: URLError(.badURL)
            )
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body, !body.isEmpty {
            request.httpBody = body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let startTime = Date()

        do {
            let (data, response) = try await session.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                return NetworkResponse(
                    statusCode: nil,
                    responseTime: responseTime,
                    data: data,
                    error: URLError(.badServerResponse)
                )
            }

            return NetworkResponse(
                statusCode: httpResponse.statusCode,
                responseTime: responseTime,
                data: data,
                error: nil
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return NetworkResponse(
                statusCode: nil,
                responseTime: responseTime,
                data: nil,
                error: error
            )
        }
    }
}
