import BackgroundTasks
import SwiftUI

@main
struct KhmNowApp: App {
    @State private var authManager = AuthManager()

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environment(authManager)
            .onAppear { registerBGTasks() }
            .task { await authManager.initialize() }
        }
    }

    private func registerBGTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.khm.KhmNow.tokenRefresh",
            using: nil
        ) { task in
            Task { @MainActor in
                await authManager.refreshIfNeeded()
                authManager.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: true)
            }
        }
    }
}
