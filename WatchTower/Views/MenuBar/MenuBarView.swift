//
//  MenuBarView.swift
//  WatchTower
//

import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Query(sort: \APIEndpoint.name) private var endpoints: [APIEndpoint]
    @EnvironmentObject private var schedulerService: SchedulerService

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            Divider()

            if endpoints.isEmpty {
                emptyStateView
            } else {
                endpointsList
            }

            Divider()

            footerSection
        }
        .frame(width: 280)
    }

    private var headerSection: some View {
        HStack {
            Text("WatchTower")
                .font(.headline)

            Spacer()

            overallStatusIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var overallStatusIndicator: some View {
        let failingCount = endpoints.filter { $0.currentStatus == .failing }.count
        let healthyCount = endpoints.filter { $0.currentStatus == .healthy }.count

        return HStack(spacing: 4) {
            if failingCount > 0 {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("\(failingCount)")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if healthyCount == endpoints.count && !endpoints.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No endpoints configured")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var endpointsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(endpoints) { endpoint in
                    MenuBarEndpointRow(endpoint: endpoint)
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private var footerSection: some View {
        HStack {
            Button("Check All") {
                Task {
                    for endpoint in endpoints {
                        await schedulerService.triggerImmediateCheck(for: endpoint)
                    }
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Open App") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "WatchTower" || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderless)

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit WatchTower")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct MenuBarEndpointRow: View {
    let endpoint: APIEndpoint
    @EnvironmentObject private var schedulerService: SchedulerService
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: endpoint.currentStatus.iconName)
                .foregroundStyle(endpoint.currentStatus.color)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(endpoint.name)
                    .font(.caption)
                    .lineLimit(1)

                if let lastCheck = endpoint.lastCheckedAt {
                    Text(lastCheck, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isHovering {
                Button(action: checkNow) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            } else if let responseTime = endpoint.lastResponseTime {
                Text(String(format: "%.0fms", responseTime * 1000))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func checkNow() {
        Task {
            await schedulerService.triggerImmediateCheck(for: endpoint)
        }
    }
}

#Preview {
    MenuBarView()
        .modelContainer(for: [APIEndpoint.self], inMemory: true)
        .environmentObject(SchedulerService())
}
