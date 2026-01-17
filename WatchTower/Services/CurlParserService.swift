//
//  CurlParserService.swift
//  WatchTower
//

import Foundation

enum CurlParseError: LocalizedError {
    case emptyCurlCommand
    case missingURL
    case invalidURL(String)
    case invalidMethod(String)

    var errorDescription: String? {
        switch self {
        case .emptyCurlCommand:
            return "The curl command is empty"
        case .missingURL:
            return "No URL found in the curl command"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidMethod(let method):
            return "Invalid HTTP method: \(method)"
        }
    }
}

struct CurlParserService {
    func parse(_ curlCommand: String) throws -> ParsedCurlCommand {
        let normalized = normalizeCurlCommand(curlCommand)

        guard !normalized.isEmpty else {
            throw CurlParseError.emptyCurlCommand
        }

        let url = try extractURL(from: normalized)
        let method = extractMethod(from: normalized)
        let headers = extractHeaders(from: normalized)
        let body = extractBody(from: normalized)

        return ParsedCurlCommand(
            url: url,
            method: method,
            headers: headers,
            body: body
        )
    }

    private func normalizeCurlCommand(_ command: String) -> String {
        var normalized = command
            .replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\\\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }

        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.lowercased().hasPrefix("curl ") {
            normalized = String(normalized.dropFirst(5))
        }

        return normalized
    }

    private func extractURL(from command: String) throws -> String {
        let patterns = [
            #"['\"]?(https?://[^\s'\"]+)['\"]?"#,
            #"(?:^|\s)([^\s]+\.[^\s]+)(?:\s|$)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: command, options: [], range: NSRange(command.startIndex..., in: command)),
               let range = Range(match.range(at: 1), in: command) {
                let url = String(command[range])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))

                if URL(string: url) != nil {
                    return url
                }
            }
        }

        throw CurlParseError.missingURL
    }

    private func extractMethod(from command: String) -> HTTPMethod {
        let methodPatterns = [
            #"-X\s*['\"]?(\w+)['\"]?"#,
            #"--request\s*['\"]?(\w+)['\"]?"#
        ]

        for pattern in methodPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: command, options: [], range: NSRange(command.startIndex..., in: command)),
               let range = Range(match.range(at: 1), in: command) {
                let methodString = String(command[range]).uppercased()
                if let method = HTTPMethod(rawValue: methodString) {
                    return method
                }
            }
        }

        if command.contains("-d ") || command.contains("--data ") ||
           command.contains("-d'") || command.contains("--data-raw ") {
            return .POST
        }

        return .GET
    }

    private func extractHeaders(from command: String) -> [String: String] {
        var headers: [String: String] = [:]

        let headerPatterns = [
            #"-H\s*['\"]([^'\"]+)['\"]"#,
            #"--header\s*['\"]([^'\"]+)['\"]"#,
            #"-H\s*([^\s]+)"#
        ]

        for pattern in headerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))

                for match in matches {
                    if let range = Range(match.range(at: 1), in: command) {
                        let headerString = String(command[range])
                        if let colonIndex = headerString.firstIndex(of: ":") {
                            let key = String(headerString[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                            let value = String(headerString[headerString.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                            if !key.isEmpty {
                                headers[key] = value
                            }
                        }
                    }
                }
            }
        }

        return headers
    }

    private func extractBody(from command: String) -> String? {
        let dataPatterns = [
            #"(?:-d|--data|--data-raw|--data-binary)\s*'([^']*)'"#,
            #"(?:-d|--data|--data-raw|--data-binary)\s*\"([^\"]*)\""#,
            #"(?:-d|--data|--data-raw|--data-binary)\s*([^\s]+)"#
        ]

        for pattern in dataPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: command, options: [], range: NSRange(command.startIndex..., in: command)),
               let range = Range(match.range(at: 1), in: command) {
                let body = String(command[range])
                if !body.isEmpty {
                    return body
                }
            }
        }

        return nil
    }
}
