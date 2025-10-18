//
//  FullAccessSection.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Full Access permission section with iOS Settings deep linking
//

import SwiftUI
import UIKit

/// Settings section for Full Access keyboard permission
/// Provides read-only status display and navigation to iOS Settings
struct FullAccessSection: View {
    
    // MARK: - Properties
    
    /// Settings manager for accessing Full Access status
    @ObservedObject var settingsManager: SettingsManager
    
    /// State for showing settings guidance overlay
    @State private var showingGuidance = false
    
    // MARK: - Body
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and title
                HStack(spacing: 12) {
                    Image(systemName: settingsManager.settings.fullAccessEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(settingsManager.settings.fullAccessEnabled ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Full Access")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(settingsManager.settings.fullAccessEnabled ? "Enabled" : "Not Enabled")
                            .font(.caption)
                            .foregroundColor(settingsManager.settings.fullAccessEnabled ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: openKeyboardSettings) {
                        Text("Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("Open iOS Settings")
                    .accessibilityHint("Opens iOS Settings to enable Full Access")
                }
                
                // Explanation text
                Text("Required for real-time scam detection while typing. TypeSafe analyzes text locally on your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Help button
                if !settingsManager.settings.fullAccessEnabled {
                    Button(action: { showingGuidance = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("How to enable Full Access")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Keyboard Permissions")
                .font(.headline)
        } footer: {
            if !settingsManager.settings.fullAccessEnabled {
                Text("Full Access allows TypeSafe to analyze text as you type. Your data stays on your device and is not stored by the keyboard.")
                    .font(.caption)
            }
        }
        .sheet(isPresented: $showingGuidance) {
            FullAccessGuidanceView()
        }
    }
    
    // MARK: - Methods
    
    /// Opens iOS Settings app to keyboard configuration
    private func openKeyboardSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            print("FullAccessSection: Invalid settings URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { success in
                if success {
                    print("FullAccessSection: Opened iOS Settings")
                } else {
                    print("FullAccessSection: Failed to open iOS Settings")
                }
            }
        }
    }
}

// MARK: - Full Access Guidance View

/// Guidance overlay showing step-by-step instructions for enabling Full Access
private struct FullAccessGuidanceView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Enable Full Access")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 20) {
                        GuidanceStep(
                            number: 1,
                            title: "Open iOS Settings",
                            description: "Tap the 'Settings' button to open your device settings"
                        )
                        
                        GuidanceStep(
                            number: 2,
                            title: "Navigate to Keyboards",
                            description: "Go to: General → Keyboard → Keyboards"
                        )
                        
                        GuidanceStep(
                            number: 3,
                            title: "Select TypeSafe",
                            description: "Find and tap on 'TypeSafe' in the keyboards list"
                        )
                        
                        GuidanceStep(
                            number: 4,
                            title: "Enable Full Access",
                            description: "Toggle 'Allow Full Access' to ON"
                        )
                        
                        GuidanceStep(
                            number: 5,
                            title: "Confirm",
                            description: "Accept the system prompt to enable Full Access"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Privacy notice
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Your Privacy is Protected")
                                .font(.headline)
                        }
                        
                        Text("Full Access allows TypeSafe to analyze text as you type, but:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            privacyPoint("Your data stays on your device")
                            privacyPoint("Text is analyzed locally")
                            privacyPoint("No keystroke logging")
                            privacyPoint("Only scan results are sent (anonymously)")
                        }
                        .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Setup Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func privacyPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Guidance Step Component

/// Individual step in the guidance overlay
private struct GuidanceStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        FullAccessSection(settingsManager: SettingsManager.shared)
    }
}

