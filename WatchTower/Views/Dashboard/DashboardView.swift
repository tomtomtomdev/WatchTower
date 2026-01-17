//
//  DashboardView.swift
//  WatchTower
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    let endpoints: [APIEndpoint]
    @Binding var selectedEndpointIDs: Set<UUID>

    @EnvironmentObject private var schedulerService: SchedulerService

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if endpoints.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(endpoints) { endpoint in
                        StatusGridItemView(
                            endpoint: endpoint,
                            isSelected: selectedEndpointIDs.contains(endpoint.id)
                        )
                        .onTapGesture {
                            handleTap(endpoint: endpoint)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: checkAllEndpoints) {
                    Label("Check All", systemImage: "arrow.clockwise")
                }
                .help("Check all endpoints now")
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Endpoints",
            systemImage: "antenna.radiowaves.left.and.right.slash",
            description: Text("Add an endpoint to start monitoring your APIs")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleTap(endpoint: APIEndpoint) {
        if NSEvent.modifierFlags.contains(.command) {
            // Command-click: toggle selection
            if selectedEndpointIDs.contains(endpoint.id) {
                selectedEndpointIDs.remove(endpoint.id)
            } else {
                selectedEndpointIDs.insert(endpoint.id)
            }
        } else if NSEvent.modifierFlags.contains(.shift) {
            // Shift-click: add to selection
            selectedEndpointIDs.insert(endpoint.id)
        } else {
            // Regular click: single selection
            selectedEndpointIDs = [endpoint.id]
        }
    }

    private func checkAllEndpoints() {
        Task {
            for endpoint in endpoints {
                await schedulerService.triggerImmediateCheck(for: endpoint)
            }
        }
    }
}

#Preview {
    DashboardView(endpoints: [], selectedEndpointIDs: .constant([]))
        .environmentObject(SchedulerService())
}
