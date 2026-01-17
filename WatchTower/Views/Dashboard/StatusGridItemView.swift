//
//  StatusGridItemView.swift
//  WatchTower
//

import SwiftUI
import SwiftData

struct StatusGridItemView: View {
    @Bindable var endpoint: APIEndpoint
    var isSelected: Bool = false

    @EnvironmentObject private var schedulerService: SchedulerService
    @State private var isHovering = false
    @State private var isChecking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIndicator
                Spacer()
                checkButton
            }

            Text(endpoint.name)
                .font(.headline)
                .lineLimit(1)

            Text(endpoint.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()

            HStack {
                if let lastCheck = endpoint.lastCheckedAt {
                    Text(lastCheck, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Never checked")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if let responseTime = endpoint.lastResponseTime {
                    Text(String(format: "%.0fms", responseTime * 1000))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isSelected ? 3 : 2)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color.secondary.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor
        } else {
            return endpoint.currentStatus.color.opacity(0.5)
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: isChecking ? "arrow.clockwise.circle.fill" : endpoint.currentStatus.iconName)
                .font(.title2)
                .foregroundStyle(isChecking ? .orange : endpoint.currentStatus.color)
                .symbolEffect(.rotate, isActive: isChecking)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var checkButton: some View {
        Button(action: triggerCheck) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .opacity(isHovering ? 1 : 0)
        .disabled(isChecking)
    }

    private func triggerCheck() {
        isChecking = true
        Task {
            await schedulerService.triggerImmediateCheck(for: endpoint)
            isChecking = false
        }
    }
}

#Preview {
    HStack {
        StatusGridItemView(endpoint: APIEndpoint(name: "Test API", url: "https://api.example.com"), isSelected: false)
        StatusGridItemView(endpoint: APIEndpoint(name: "Selected API", url: "https://api.example.com"), isSelected: true)
    }
    .environmentObject(SchedulerService())
    .padding()
    .frame(width: 420, height: 140)
}
