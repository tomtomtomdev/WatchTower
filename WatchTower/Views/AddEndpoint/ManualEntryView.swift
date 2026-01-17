//
//  ManualEntryView.swift
//  WatchTower
//

import SwiftUI

struct ManualEntryView: View {
    let onSave: (APIEndpoint) -> Void

    @State private var name = ""
    @State private var url = ""
    @State private var method: HTTPMethod = .GET
    @State private var pollingInterval: PollingInterval = .fifteenMinutes
    @State private var headerPairs: [HeaderPair] = []
    @State private var requestBody = ""
    @State private var showRequestBody = false

    struct HeaderPair: Identifiable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }

    var body: some View {
        Form {
            Section {
                TextField("Endpoint Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Name")
            }

            Section {
                TextField("https://api.example.com/health", text: $url)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("URL")
            }

            Section {
                Picker("Method", selection: $method) {
                    ForEach(HTTPMethod.allCases) { httpMethod in
                        Text(httpMethod.rawValue).tag(httpMethod)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("HTTP Method")
            }

            Section {
                ForEach($headerPairs) { $pair in
                    HStack {
                        TextField("Header Name", text: $pair.key)
                            .textFieldStyle(.roundedBorder)
                        TextField("Value", text: $pair.value)
                            .textFieldStyle(.roundedBorder)
                        Button(action: { removeHeader(pair) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button(action: addHeader) {
                    Label("Add Header", systemImage: "plus")
                }
            } header: {
                Text("Headers")
            }

            if method != .GET && method != .HEAD {
                Section {
                    Toggle("Include Request Body", isOn: $showRequestBody)

                    if showRequestBody {
                        TextEditor(text: $requestBody)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                } header: {
                    Text("Body")
                }
            }

            Section {
                Picker("Polling Interval", selection: $pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
            } header: {
                Text("Monitoring")
            }

            Section {
                Button(action: createEndpoint) {
                    Text("Add Endpoint")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .formStyle(.grouped)
    }

    private var isValid: Bool {
        !name.isEmpty && !url.isEmpty && URL(string: url) != nil
    }

    private func addHeader() {
        headerPairs.append(HeaderPair())
    }

    private func removeHeader(_ pair: HeaderPair) {
        headerPairs.removeAll { $0.id == pair.id }
    }

    private func createEndpoint() {
        var headers: [String: String] = [:]
        for pair in headerPairs where !pair.key.isEmpty {
            headers[pair.key] = pair.value
        }

        let endpoint = APIEndpoint(
            name: name,
            url: url,
            method: method,
            headers: headers,
            body: showRequestBody && !requestBody.isEmpty ? requestBody : nil,
            pollingInterval: pollingInterval
        )

        onSave(endpoint)
    }
}

#Preview {
    ManualEntryView { _ in }
        .frame(width: 500, height: 600)
}
