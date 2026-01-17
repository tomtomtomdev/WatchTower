//
//  EndpointListView.swift
//  WatchTower
//

import SwiftUI
import SwiftData

struct EndpointListView: View {
    let endpoints: [APIEndpoint]
    @Binding var selectedEndpointIDs: Set<UUID>

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var schedulerService: SchedulerService

    var body: some View {
        List(selection: $selectedEndpointIDs) {
            Section {
                ForEach(endpoints) { endpoint in
                    EndpointRowView(endpoint: endpoint)
                        .tag(endpoint.id)
                        .contextMenu {
                            contextMenuItems(for: endpoint)
                        }
                }
                .onDelete(perform: deleteEndpoints)
            } header: {
                HStack {
                    Text("Endpoints")
                    Spacer()
                    Text("\(endpoints.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("WatchTower")
        .contextMenu(forSelectionType: UUID.self) { selectedIDs in
            if selectedIDs.count > 1 {
                bulkContextMenu(for: selectedIDs)
            }
        } primaryAction: { selectedIDs in
            // Double-click action - could open detail view
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                if selectedEndpointIDs.count > 1 {
                    Menu {
                        bulkContextMenu(for: selectedEndpointIDs)
                    } label: {
                        Label("Bulk Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for endpoint: APIEndpoint) -> some View {
        Button(action: { checkNow(endpoint) }) {
            Label("Check Now", systemImage: "arrow.clockwise")
        }

        Divider()

        Button(action: { toggleEnabled(endpoint) }) {
            Label(
                endpoint.isEnabled ? "Disable" : "Enable",
                systemImage: endpoint.isEnabled ? "pause.circle" : "play.circle"
            )
        }

        Divider()

        Button(role: .destructive, action: { deleteEndpoint(endpoint) }) {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func bulkContextMenu(for selectedIDs: Set<UUID>) -> some View {
        let selectedEndpoints = endpoints.filter { selectedIDs.contains($0.id) }

        Button(action: { checkNowBulk(selectedEndpoints) }) {
            Label("Check All Selected (\(selectedEndpoints.count))", systemImage: "arrow.clockwise")
        }

        Divider()

        Button(action: { enableBulk(selectedEndpoints) }) {
            Label("Enable All Selected", systemImage: "play.circle")
        }

        Button(action: { disableBulk(selectedEndpoints) }) {
            Label("Disable All Selected", systemImage: "pause.circle")
        }

        Divider()

        Button(role: .destructive, action: { deleteBulk(selectedEndpoints) }) {
            Label("Delete All Selected (\(selectedEndpoints.count))", systemImage: "trash")
        }
    }

    private func deleteEndpoints(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(endpoints[index])
        }
    }

    private func deleteEndpoint(_ endpoint: APIEndpoint) {
        selectedEndpointIDs.remove(endpoint.id)
        modelContext.delete(endpoint)
    }

    private func toggleEnabled(_ endpoint: APIEndpoint) {
        endpoint.isEnabled.toggle()
        schedulerService.restartMonitoring(endpoint: endpoint)
    }

    private func checkNow(_ endpoint: APIEndpoint) {
        Task {
            await schedulerService.triggerImmediateCheck(for: endpoint)
        }
    }

    // MARK: - Bulk Actions

    private func checkNowBulk(_ endpoints: [APIEndpoint]) {
        Task {
            await schedulerService.triggerBatchHealthChecks(for: endpoints)
        }
    }

    private func enableBulk(_ endpoints: [APIEndpoint]) {
        for endpoint in endpoints {
            endpoint.isEnabled = true
            schedulerService.restartMonitoring(endpoint: endpoint)
        }
    }

    private func disableBulk(_ endpoints: [APIEndpoint]) {
        for endpoint in endpoints {
            endpoint.isEnabled = false
            schedulerService.stopMonitoring(endpoint: endpoint)
        }
    }

    private func deleteBulk(_ endpoints: [APIEndpoint]) {
        for endpoint in endpoints {
            selectedEndpointIDs.remove(endpoint.id)
            modelContext.delete(endpoint)
        }
    }
}

#Preview {
    EndpointListView(endpoints: [], selectedEndpointIDs: .constant([]))
        .environmentObject(SchedulerService())
}
