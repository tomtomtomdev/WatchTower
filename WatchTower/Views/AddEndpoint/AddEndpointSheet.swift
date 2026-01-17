//
//  AddEndpointSheet.swift
//  WatchTower
//

import SwiftUI
import SwiftData

struct AddEndpointSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    enum Tab: String, CaseIterable {
        case curlImport = "Import from cURL"
        case manual = "Manual Entry"
    }

    @State private var selectedTab: Tab = .curlImport

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                CurlImportView(onSave: saveEndpoint, onBulkSave: saveBulkEndpoints)
                    .tabItem { Text("Import cURL") }
                    .tag(Tab.curlImport)

                ManualEntryView(onSave: saveEndpoint)
                    .tabItem { Text("Manual Entry") }
                    .tag(Tab.manual)
            }
            .padding()
            .navigationTitle("Add Endpoint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 500)
    }

    private func saveEndpoint(_ endpoint: APIEndpoint) {
        modelContext.insert(endpoint)
        try? modelContext.save()
        dismiss()
    }

    private func saveBulkEndpoints(_ endpoints: [APIEndpoint]) {
        for endpoint in endpoints {
            modelContext.insert(endpoint)
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddEndpointSheet()
        .modelContainer(for: [APIEndpoint.self], inMemory: true)
}
