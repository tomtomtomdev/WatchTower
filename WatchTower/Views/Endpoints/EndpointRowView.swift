//
//  EndpointRowView.swift
//  WatchTower
//

import SwiftUI
import SwiftData

struct EndpointRowView: View {
    let endpoint: APIEndpoint

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: endpoint.currentStatus.iconName)
                .foregroundStyle(endpoint.currentStatus.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(endpoint.name)
                    .font(.body)
                    .lineLimit(1)

                Text(endpoint.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            if !endpoint.isEnabled {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EndpointRowView(endpoint: APIEndpoint(name: "Test API", url: "https://api.example.com"))
        .padding()
}
