//
//  WatchTowerApp.swift
//  WatchTower
//

import SwiftUI
import SwiftData

@main
struct WatchTowerApp: App {
    let modelContainer: ModelContainer
    @StateObject private var schedulerService = SchedulerService()
    @StateObject private var notificationService = NotificationService.shared

    init() {
        do {
            let schema = Schema([
                APIEndpoint.self,
                HealthCheckResult.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .modelContainer(modelContainer)
                .environmentObject(schedulerService)
                .onAppear {
                    setupServices()
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 700)

        MenuBarExtra("WatchTower", systemImage: menuBarIcon) {
            MenuBarView()
                .modelContainer(modelContainer)
                .environmentObject(schedulerService)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<APIEndpoint>()

        do {
            let endpoints = try context.fetch(descriptor)
            let hasFailure = endpoints.contains { $0.currentStatus == .failing }
            return hasFailure ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right"
        } catch {
            return "antenna.radiowaves.left.and.right"
        }
    }

    private func setupServices() {
        let context = modelContainer.mainContext
        let healthCheckService = HealthCheckService(
            modelContext: context,
            notificationService: notificationService
        )
        schedulerService.configure(
            healthCheckService: healthCheckService,
            modelContext: context
        )

        notificationService.setupNotificationCategories()

        Task {
            await notificationService.requestAuthorization()
        }

        loadAndStartMonitoring()
    }

    private func loadAndStartMonitoring() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<APIEndpoint>()

        do {
            let endpoints = try context.fetch(descriptor)
            schedulerService.startMonitoring(endpoints: endpoints)
        } catch {
            print("Failed to fetch endpoints: \(error)")
        }
    }
}
