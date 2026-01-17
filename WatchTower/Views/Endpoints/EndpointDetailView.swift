//
//  EndpointDetailView.swift
//  WatchTower
//

import SwiftUI
import SwiftData
import Charts

struct EndpointDetailView: View {
    @Bindable var endpoint: APIEndpoint
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var schedulerService: SchedulerService

    @State private var isEditing = false
    @State private var isChecking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                statusSection
                configurationSection
                historySection
            }
            .padding()
        }
        .navigationTitle(endpoint.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: checkNow) {
                    Label("Check Now", systemImage: "arrow.clockwise")
                }
                .disabled(isChecking)

                Button(action: { isEditing = true }) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditEndpointSheet(endpoint: endpoint)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: endpoint.currentStatus.iconName)
                    .font(.largeTitle)
                    .foregroundStyle(endpoint.currentStatus.color)

                VStack(alignment: .leading) {
                    Text(endpoint.currentStatus.rawValue.capitalized)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let lastCheck = endpoint.lastCheckedAt {
                        Text("Last checked \(lastCheck, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("Enabled", isOn: $endpoint.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Text(endpoint.url)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)

            if let responseTime = endpoint.lastResponseTime {
                HStack {
                    Label("Response Time", systemImage: "clock")
                    Spacer()
                    Text(String(format: "%.0f ms", responseTime * 1000))
                        .fontWeight(.medium)
                }
            }

            if let lastResult = endpoint.healthCheckResults.sorted(by: { $0.timestamp > $1.timestamp }).first,
               let statusCode = lastResult.statusCode {
                HStack {
                    Label("Status Code", systemImage: "number")
                    Spacer()
                    Text("\(statusCode)")
                        .fontWeight(.medium)
                        .foregroundStyle(statusCode < 400 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.headline)

            LabeledContent("Method", value: endpoint.method.rawValue)
            LabeledContent("Polling Interval", value: endpoint.pollingInterval.displayName)

            if !endpoint.headers.isEmpty {
                DisclosureGroup("Headers (\(endpoint.headers.count))") {
                    ForEach(Array(endpoint.headers.keys.sorted()), id: \.self) { key in
                        LabeledContent(key, value: endpoint.headers[key] ?? "")
                    }
                }
            }

            if let body = endpoint.body, !body.isEmpty {
                DisclosureGroup("Body") {
                    Text(body)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent History")
                .font(.headline)

            let recentResults = endpoint.healthCheckResults
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(10)

            if recentResults.isEmpty {
                Text("No health check history yet")
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                responseTimeChart(results: Array(recentResults.reversed()))

                ForEach(Array(recentResults)) { result in
                    HStack {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.isSuccess ? .green : .red)

                        VStack(alignment: .leading) {
                            Text(result.timestamp, style: .date)
                                .font(.caption)
                            Text(result.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let statusCode = result.statusCode {
                            Text("\(statusCode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(String(format: "%.0fms", result.responseTime * 1000))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func responseTimeChart(results: [HealthCheckResult]) -> some View {
        if results.count > 1 {
            Chart(results) { result in
                LineMark(
                    x: .value("Time", result.timestamp),
                    y: .value("Response Time", result.responseTime * 1000)
                )
                .foregroundStyle(result.isSuccess ? Color.green : Color.red)

                PointMark(
                    x: .value("Time", result.timestamp),
                    y: .value("Response Time", result.responseTime * 1000)
                )
                .foregroundStyle(result.isSuccess ? Color.green : Color.red)
            }
            .chartYAxisLabel("ms")
            .frame(height: 150)
        }
    }

    private func checkNow() {
        isChecking = true
        Task {
            await schedulerService.triggerImmediateCheck(for: endpoint)
            isChecking = false
        }
    }
}

struct EditEndpointSheet: View {
    @Bindable var endpoint: APIEndpoint
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $endpoint.name)
                    TextField("URL", text: $endpoint.url)
                }

                Section("Request") {
                    Picker("Method", selection: $endpoint.method) {
                        ForEach(HTTPMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                }

                Section("Monitoring") {
                    Picker("Polling Interval", selection: $endpoint.pollingInterval) {
                        ForEach(PollingInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }

                    Toggle("Enabled", isOn: $endpoint.isEnabled)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Endpoint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    EndpointDetailView(endpoint: APIEndpoint(name: "Test API", url: "https://api.example.com"))
        .environmentObject(SchedulerService())
}
