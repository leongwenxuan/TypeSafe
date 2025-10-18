//
//  MainTabView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import SwiftUI

/// Main tab navigation view for the TypeSafe app
/// Provides three primary tabs: Scan, History, and Settings
struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScanView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Scan")
                }
                .tag(0)
                .accessibilityLabel("Scan tab")
                .accessibilityHint("Scan your screen for potential scams")
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
                .tag(1)
                .accessibilityLabel("History tab")
                .accessibilityHint("View your recent scan results")
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
                .accessibilityLabel("Settings tab")
                .accessibilityHint("Configure privacy and app settings")
        }
        .accentColor(.blue) // TypeSafe brand color consistent with keyboard extension
        .onChange(of: deepLinkCoordinator.shouldNavigateToScan) { shouldNavigate in
            if shouldNavigate {
                print("MainTabView: Deep link triggered - navigating to scan tab")
                selectedTab = 0 // Navigate to scan tab
            }
        }
        .onChange(of: deepLinkCoordinator.shouldNavigateToSettings) { shouldNavigate in
            if shouldNavigate {
                print("MainTabView: Deep link triggered - navigating to settings tab")
                selectedTab = 2 // Navigate to settings tab
            }
        }
        .onAppear {
            // Configure tab bar appearance for consistent branding
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            // Set selected and unselected item colors
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
}
