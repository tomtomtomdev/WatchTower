//
//  PostmanParserService.swift
//  WatchTower
//

import Foundation

// MARK: - Postman Collection Models

struct PostmanCollection: Codable {
    let info: PostmanInfo?
    let item: [PostmanItem]
}

struct PostmanInfo: Codable {
    let name: String?
    let schema: String?
}

struct PostmanItem: Codable {
    let name: String?
    let request: PostmanRequest?
    let item: [PostmanItem]?  // Nested folders
}

struct PostmanRequest: Codable {
    let method: String?
    let header: [PostmanHeader]?
    let body: PostmanBody?
    let url: PostmanURL

    enum CodingKeys: String, CodingKey {
        case method, header, body, url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        header = try container.decodeIfPresent([PostmanHeader].self, forKey: .header)
        body = try container.decodeIfPresent(PostmanBody.self, forKey: .body)

        // URL can be either a string or an object
        if let urlString = try? container.decode(String.self, forKey: .url) {
            url = PostmanURL(raw: urlString)
        } else {
            url = try container.decode(PostmanURL.self, forKey: .url)
        }
    }
}

struct PostmanURL: Codable {
    let raw: String?
    let host: [String]?
    let path: [String]?
    let query: [PostmanQuery]?
    let variable: [PostmanVariable]?

    init(raw: String) {
        self.raw = raw
        self.host = nil
        self.path = nil
        self.query = nil
        self.variable = nil
    }

    var resolvedURL: String? {
        if let raw = raw, !raw.isEmpty {
            return raw
        }

        // Build URL from components
        guard let host = host, !host.isEmpty else { return nil }
        var urlString = "https://" + host.joined(separator: ".")
        if let path = path, !path.isEmpty {
            urlString += "/" + path.joined(separator: "/")
        }
        if let query = query, !query.isEmpty {
            let queryString = query.compactMap { q -> String? in
                guard let key = q.key else { return nil }
                return "\(key)=\(q.value ?? "")"
            }.joined(separator: "&")
            if !queryString.isEmpty {
                urlString += "?" + queryString
            }
        }
        return urlString
    }
}

struct PostmanHeader: Codable {
    let key: String?
    let value: String?
    let disabled: Bool?
}

struct PostmanBody: Codable {
    let mode: String?
    let raw: String?
    let urlencoded: [PostmanURLEncoded]?
    let formdata: [PostmanFormData]?

    var resolvedBody: String? {
        switch mode {
        case "raw":
            return raw
        case "urlencoded":
            guard let urlencoded = urlencoded else { return nil }
            return urlencoded.compactMap { item -> String? in
                guard let key = item.key, item.disabled != true else { return nil }
                return "\(key)=\(item.value ?? "")"
            }.joined(separator: "&")
        case "formdata":
            // Form data is typically handled differently, return as JSON representation
            guard let formdata = formdata else { return nil }
            let pairs = formdata.compactMap { item -> (String, String)? in
                guard let key = item.key, item.disabled != true else { return nil }
                return (key, item.value ?? "")
            }
            if pairs.isEmpty { return nil }
            let dict = Dictionary(uniqueKeysWithValues: pairs)
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return nil
        default:
            return raw
        }
    }
}

struct PostmanURLEncoded: Codable {
    let key: String?
    let value: String?
    let disabled: Bool?
}

struct PostmanFormData: Codable {
    let key: String?
    let value: String?
    let type: String?
    let disabled: Bool?
}

struct PostmanQuery: Codable {
    let key: String?
    let value: String?
    let disabled: Bool?
}

struct PostmanVariable: Codable {
    let key: String?
    let value: String?
}

// MARK: - Parse Errors

enum PostmanParseError: LocalizedError {
    case invalidJSON
    case emptyCollection
    case noValidRequests

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid Postman collection JSON format"
        case .emptyCollection:
            return "The Postman collection is empty"
        case .noValidRequests:
            return "No valid requests found in the collection"
        }
    }
}

// MARK: - Parsed Postman Request

struct ParsedPostmanRequest: Identifiable {
    let id = UUID()
    var name: String
    let parsedCommand: ParsedCurlCommand
    var isSelected: Bool = true
    let folderPath: String?

    var isValid: Bool { true }
}

// MARK: - Parser Service

struct PostmanParserService {

    func parse(_ jsonData: Data) throws -> [ParsedPostmanRequest] {
        let decoder = JSONDecoder()

        let collection: PostmanCollection
        do {
            collection = try decoder.decode(PostmanCollection.self, from: jsonData)
        } catch {
            throw PostmanParseError.invalidJSON
        }

        guard !collection.item.isEmpty else {
            throw PostmanParseError.emptyCollection
        }

        var requests: [ParsedPostmanRequest] = []
        extractRequests(from: collection.item, folderPath: nil, into: &requests)

        guard !requests.isEmpty else {
            throw PostmanParseError.noValidRequests
        }

        return requests
    }

    func parse(_ jsonString: String) throws -> [ParsedPostmanRequest] {
        guard let data = jsonString.data(using: .utf8) else {
            throw PostmanParseError.invalidJSON
        }
        return try parse(data)
    }

    private func extractRequests(
        from items: [PostmanItem],
        folderPath: String?,
        into requests: inout [ParsedPostmanRequest]
    ) {
        for item in items {
            // If this item has nested items, it's a folder
            if let nestedItems = item.item, !nestedItems.isEmpty {
                let newPath = folderPath.map { "\($0)/\(item.name ?? "Folder")" } ?? item.name
                extractRequests(from: nestedItems, folderPath: newPath, into: &requests)
            }

            // If this item has a request, parse it
            if let request = item.request {
                if let parsedRequest = parseRequest(item: item, request: request, folderPath: folderPath) {
                    requests.append(parsedRequest)
                }
            }
        }
    }

    private func parseRequest(
        item: PostmanItem,
        request: PostmanRequest,
        folderPath: String?
    ) -> ParsedPostmanRequest? {
        // Get URL
        guard let urlString = request.url.resolvedURL, !urlString.isEmpty else {
            return nil
        }

        // Get method
        let methodString = request.method?.uppercased() ?? "GET"
        let method = HTTPMethod(rawValue: methodString) ?? .GET

        // Get headers
        var headers: [String: String] = [:]
        if let requestHeaders = request.header {
            for header in requestHeaders where header.disabled != true {
                if let key = header.key, let value = header.value {
                    headers[key] = value
                }
            }
        }

        // Get body
        let body = request.body?.resolvedBody

        // Create parsed command
        let parsedCommand = ParsedCurlCommand(
            url: urlString,
            method: method,
            headers: headers,
            body: body
        )

        // Generate name
        let name = item.name ?? extractEndpointName(from: urlString)

        return ParsedPostmanRequest(
            name: name,
            parsedCommand: parsedCommand,
            folderPath: folderPath
        )
    }

    private func extractEndpointName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return "New Endpoint"
        }

        var path = url.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        if path.isEmpty {
            return url.host ?? "New Endpoint"
        }

        if path.hasSuffix("/") {
            path = String(path.dropLast())
        }

        if path.count > 40 {
            return url.lastPathComponent.isEmpty ? (url.host ?? "New Endpoint") : url.lastPathComponent
        }

        return path
    }
}
