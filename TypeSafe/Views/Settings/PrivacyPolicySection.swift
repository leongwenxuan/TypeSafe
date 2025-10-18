//
//  PrivacyPolicySection.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Privacy policy and app version information section
//

import SwiftUI

/// Settings section for legal information and app version
/// Provides access to privacy policy and displays app version
struct PrivacyPolicySection: View {
    
    // MARK: - Properties
    
    /// Settings manager for privacy policy acceptance tracking
    @ObservedObject var settingsManager: SettingsManager
    
    /// State for showing Safari privacy policy view
    @State private var showingPrivacyPolicy = false
    
    /// State for showing about alert
    @State private var showingAboutInfo = false
    
    // MARK: - Computed Properties
    
    /// App version from Bundle
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
    /// App name from Bundle
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "TypeSafe"
    }
    
    /// Privacy policy URL (update with actual URL when available)
    private var privacyPolicyURL: URL {
        // TODO: Replace with actual privacy policy URL before production
        URL(string: "https://typesafe.app/privacy") ?? URL(string: "https://apple.com")!
    }
    
    // MARK: - Body
    
    var body: some View {
        Section {
            // Privacy Policy Button
            Button(action: { showingPrivacyPolicy = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy Policy")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if settingsManager.settings.privacyPolicyAccepted {
                            Text("Last accepted: \(formattedSyncDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not yet accepted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.circle")
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Privacy Policy")
            .accessibilityHint("Opens privacy policy in Safari")
            
            // Terms of Service (Optional)
            Button(action: { showingAboutInfo = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.plaintext.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Terms of Service")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("View our terms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.circle")
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Terms of Service")
            
            // App Version Information
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Version")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(appVersion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App Version: \(appVersion)")
            
        } header: {
            Text("Legal & About")
                .font(.headline)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("© 2025 TypeSafe. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("TypeSafe is designed to protect you from online scams with privacy-first principles.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyWebView(
                settingsManager: settingsManager,
                url: privacyPolicyURL
            )
        }
        .alert("Terms of Service", isPresented: $showingAboutInfo) {
            Button("View Online") {
                // Open terms in Safari
                if let url = URL(string: "https://typesafe.app/terms") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("View our terms of service online at typesafe.app/terms")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Formatted sync date for display
    private var formattedSyncDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: settingsManager.settings.lastSettingsSync)
    }
}

// MARK: - Privacy Policy Web View

/// Web view wrapper for displaying privacy policy with acceptance tracking
private struct PrivacyPolicyWebView: View {
    
    @ObservedObject var settingsManager: SettingsManager
    let url: URL
    
    @Environment(\.dismiss) var dismiss
    @State private var hasAccepted = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Safari view
                SafariView(url: url)
                
                // Accept button (if not yet accepted)
                if !settingsManager.settings.privacyPolicyAccepted && !hasAccepted {
                    VStack(spacing: 12) {
                        Button(action: acceptPrivacyPolicy) {
                            Text("I Accept")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Text("By accepting, you agree to our privacy policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Privacy Policy")
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
    
    private func acceptPrivacyPolicy() {
        hasAccepted = true
        settingsManager.acceptPrivacyPolicy()
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        PrivacyPolicySection(settingsManager: SettingsManager.shared)
    }
}

