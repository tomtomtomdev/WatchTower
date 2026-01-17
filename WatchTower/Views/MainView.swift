//
//  MainView.swift
//  WatchTower
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \APIEndpoint.name) private var endpoints: [APIEndpoint]

    @State private var selectedEndpointIDs: Set<UUID> = []
    @State private var showingAddEndpoint = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    @EnvironmentObject private var schedulerService: SchedulerService

    enum ViewMode: String, CaseIterable {
        case dashboard = "Dashboard"
        case list = "List"
    }

    @State private var viewMode: ViewMode = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddEndpoint) {
            AddEndpointSheet()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button(action: { showingAddEndpoint = true }) {
                    Label("Add Endpoint", systemImage: "plus")
                }
            }
        }
        .onAppear {
            schedulerService.startMonitoring(endpoints: endpoints)
        }
    }

    private var sidebar: some View {
        EndpointListView(
            endpoints: endpoints,
            selectedEndpointIDs: $selectedEndpointIDs
        )
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
    }

    private var selectedEndpoints: [APIEndpoint] {
        endpoints.filter { selectedEndpointIDs.contains($0.id) }
    }

    private var firstSelectedEndpoint: APIEndpoint? {
        guard let firstID = selectedEndpointIDs.first else { return nil }
        return endpoints.first { $0.id == firstID }
    }

    @ViewBuilder
    private var detailView: some View {
        switch viewMode {
        case .dashboard:
            DashboardView(endpoints: endpoints, selectedEndpointIDs: $selectedEndpointIDs)
        case .list:
            if selectedEndpointIDs.isEmpty {
                ContentUnavailableView(
                    "Select an Endpoint",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Choose an endpoint from the sidebar to view its details")
                )
            } else if selectedEndpointIDs.count == 1, let endpoint = firstSelectedEndpoint {
                EndpointDetailView(endpoint: endpoint)
            } else {
                MultipleSelectionView(endpoints: selectedEndpoints)
            }
        }
    }
}

// MARK: - Multiple Selection View

struct MultipleSelectionView: View {
    let endpoints: [APIEndpoint]
    @EnvironmentObject private var schedulerService: SchedulerService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("\(endpoints.count) Endpoints Selected")
                .font(.title2)
                .fontWeight(.semibold)

            statusSummary

            Divider()
                .padding(.horizontal, 40)

            bulkActionsView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var statusSummary: some View {
        HStack(spacing: 24) {
            let healthy = endpoints.filter { $0.currentStatus == .healthy }.count
            let failing = endpoints.filter { $0.currentStatus == .failing }.count
            let unknown = endpoints.filter { $0.currentStatus == .unknown }.count
            let enabled = endpoints.filter { $0.isEnabled }.count

            StatusBadge(count: healthy, label: "Healthy", color: .green)
            StatusBadge(count: failing, label: "Failing", color: .red)
            StatusBadge(count: unknown, label: "Unknown", color: .gray)
            StatusBadge(count: enabled, label: "Enabled", color: .blue)
        }
    }

    private var bulkActionsView: some View {
        VStack(spacing: 12) {
            Text("Bulk Actions")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button(action: checkAllNow) {
                    Label("Check All Now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button(action: enableAll) {
                    Label("Enable All", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)

                Button(action: disableAll) {
                    Label("Disable All", systemImage: "pause.circle")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: deleteAll) {
                    Label("Delete All", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func checkAllNow() {
        Task {
            for endpoint in endpoints {
                await schedulerService.triggerImmediateCheck(for: endpoint)
            }
        }
    }

    private func enableAll() {
        for endpoint in endpoints {
            endpoint.isEnabled = true
            schedulerService.restartMonitoring(endpoint: endpoint)
        }
    }

    private func disableAll() {
        for endpoint in endpoints {
            endpoint.isEnabled = false
            schedulerService.stopMonitoring(endpoint: endpoint)
        }
    }

    private func deleteAll() {
        for endpoint in endpoints {
            modelContext.delete(endpoint)
        }
    }
}

struct StatusBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [APIEndpoint.self, HealthCheckResult.self], inMemory: true)
        .environmentObject(SchedulerService())
}
