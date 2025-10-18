//
//  SettingsView.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Comprehensive settings view with privacy controls, data management, and legal information
//

import SwiftUI

/// Main settings view for TypeSafe app
/// Provides comprehensive privacy controls, data management, and app information
struct SettingsView: View {
    
    // MARK: - Properties
    
    /// Settings manager for all app settings
    @StateObject private var settingsManager = SettingsManager.shared
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Full Access Keyboard Permission
                FullAccessSection(settingsManager: settingsManager)
                
                // Privacy Controls (Screenshot Upload, Notifications)
                PrivacySection(settingsManager: settingsManager)
                
                // Screenshot Scanning (Automatic scan and Photos permission) - Story 5.1
                ScreenshotScanningSection(settingsManager: settingsManager)
                
                // Voice Alerts (Optional, Future Feature)
                VoiceAlertsSection(settingsManager: settingsManager)
                
                // Data Management (Delete All Data)
                DataManagementSection(settingsManager: settingsManager)
                
                // Privacy Policy and App Version
                PrivacyPolicySection(settingsManager: settingsManager)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Load settings from App Group on appear
                settingsManager.loadSettingsFromAppGroup()
                print("SettingsView: Loaded settings on appear")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
