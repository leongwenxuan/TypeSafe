//
//  PrivacySection.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Privacy controls section for screenshot image upload and notifications
//

import SwiftUI

/// Settings section for privacy controls
/// Includes screenshot image upload toggle and notification preferences
struct PrivacySection: View {
    
    // MARK: - Properties
    
    /// Settings manager for privacy controls
    @ObservedObject var settingsManager: SettingsManager
    
    /// State for showing privacy information alert
    @State private var showingPrivacyInfo = false
    
    // MARK: - Body
    
    var body: some View {
        Section {
            // Screenshot Image Upload Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.sendScreenshotImages },
                    set: { settingsManager.updateScreenshotImageSetting($0) }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Screenshot Images")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(settingsManager.settings.sendScreenshotImages ? "Enhanced analysis enabled" : "Privacy-first mode")
                                .font(.caption)
                                .foregroundColor(settingsManager.settings.sendScreenshotImages ? .orange : .green)
                        }
                    }
                }
                .accessibilityLabel("Send Screenshot Images")
                .accessibilityHint("Toggle whether to send screenshots for enhanced analysis")
                
                // Contextual explanation
                privacyExplanationView
            }
            .padding(.vertical, 8)
            
            // Notification Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.scanResultNotifications },
                    set: { settingsManager.updateNotificationsSetting($0) }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Result Notifications")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("Show banner in keyboard")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .accessibilityLabel("Scan Result Notifications")
                .accessibilityHint("Toggle whether to show scan results in keyboard banner")
            }
            .padding(.vertical, 8)
            
        } header: {
            Text("Privacy Controls")
                .font(.headline)
        } footer: {
            Text("TypeSafe is designed with privacy-first principles. You control what data is shared.")
                .font(.caption)
        }
        .alert("Screenshot Privacy Information", isPresented: $showingPrivacyInfo) {
            Button("OK") { }
        } message: {
            Text(privacyInfoMessage)
        }
    }
    
    // MARK: - Subviews
    
    /// Contextual explanation based on current setting
    private var privacyExplanationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settingsManager.settings.sendScreenshotImages {
                // Images enabled - show warning
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enhanced Analysis Mode")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("Screenshots are sent to our secure servers for analysis and deleted immediately after processing.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { showingPrivacyInfo = true }) {
                    Text("Learn more about screenshot privacy")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            } else {
                // Images disabled - show privacy assurance
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum Privacy Mode")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text("Only extracted text is analyzed. Screenshots stay on your device.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    privacyBullet("Screenshots never leave your device")
                    privacyBullet("Only text is sent for analysis")
                    privacyBullet("No visual context shared")
                }
                .padding(.leading, 24)
            }
        }
        .padding(12)
        .background(
            settingsManager.settings.sendScreenshotImages ?
            Color.orange.opacity(0.1) : Color.green.opacity(0.1)
        )
        .cornerRadius(8)
    }
    
    /// Privacy bullet point
    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Content
    
    /// Detailed privacy information message
    private var privacyInfoMessage: String {
        """
        When enabled:
        • Screenshots are sent to our secure backend
        • Images are processed and deleted immediately
        • May provide better context for scam detection
        
        When disabled (default):
        • Only text extracted via OCR is sent
        • Screenshots never leave your device
        • Maximum privacy protection
        
        You can change this setting anytime.
        """
    }
}

// MARK: - Preview

#Preview {
    Form {
        PrivacySection(settingsManager: SettingsManager.shared)
    }
}

