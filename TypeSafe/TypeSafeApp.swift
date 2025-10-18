//
//  TypeSafeApp.swift
//  TypeSafe
//
//  Created by Daniel on 18/10/25.
//

import SwiftUI
import CoreData
import Combine

@main
struct TypeSafeApp: App {
    /// Core Data persistence controller
    let persistenceController = PersistenceController.shared
    
    /// Screenshot notification manager
    @StateObject private var screenshotManager = ScreenshotNotificationManagerWrapper()
    
    /// Deep link coordinator for handling URL schemes
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(deepLinkCoordinator)
                .onAppear {
                    print("🟢 ========== APP APPEARED ==========")
                    
                    // Perform daily cleanup on app launch
                    HistoryManager.shared.performDailyCleanup()
                    
                    // Register for screenshot notifications (Story 4.1)
                    print("🟢 Registering for screenshot notifications...")
                    screenshotManager.registerForNotifications()
                    
                    print("🟢 ========== APP SETUP COMPLETE ==========")
                }
                .onOpenURL { url in
                    // Handle deep links (Story 4.2)
                    deepLinkCoordinator.handleURL(url)
                }
        }
    }
}

/// Wrapper class to make ScreenshotNotificationManager work with @StateObject
/// This ensures the manager stays alive for the app's lifetime
private class ScreenshotNotificationManagerWrapper: ObservableObject {
    /// Required for ObservableObject conformance
    let objectWillChange = ObservableObjectPublisher()
    
    func registerForNotifications() {
        ScreenshotNotificationManager.shared.registerForScreenshotNotifications()
        
        // Clean up expired notifications on app launch
        ScreenshotNotificationManager.shared.cleanupExpiredNotifications()
    }
    
    deinit {
        ScreenshotNotificationManager.shared.unregisterFromScreenshotNotifications()
    }
}

/// Deep link coordinator for handling URL schemes (Story 4.2, enhanced in Story 5.2)
/// Manages navigation to scan view when keyboard triggers typesafe://scan or typesafe://scan?auto=true
class DeepLinkCoordinator: ObservableObject {
    /// Published property to trigger navigation to scan tab
    @Published var shouldNavigateToScan: Bool = false
    
    /// Published property to trigger automatic scanning (Story 5.2)
    @Published var shouldAutoScan: Bool = false
    
    /// Handles incoming URL schemes
    /// - Parameter url: The URL to handle (e.g., typesafe://scan or typesafe://scan?auto=true)
    func handleURL(_ url: URL) {
        print("DeepLinkCoordinator: Received URL: \(url.absoluteString)")
        
        guard url.scheme == "typesafe" else {
            print("DeepLinkCoordinator: Unknown URL scheme: \(url.scheme ?? "none")")
            return
        }
        
        switch url.host {
        case "scan":
            print("DeepLinkCoordinator: Navigating to scan view")
            
            // Parse query parameters (Story 5.2)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let autoParam = components?.queryItems?.first(where: { $0.name == "auto" })
            
            shouldNavigateToScan = true
            shouldAutoScan = (autoParam?.value == "true")
            
            print("DeepLinkCoordinator: auto=\(shouldAutoScan)")
            
            // Reset after a short delay to allow repeated triggers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.shouldNavigateToScan = false
                self.shouldAutoScan = false
            }
            
        default:
            print("DeepLinkCoordinator: Unknown URL host: \(url.host ?? "none")")
        }
    }
}
