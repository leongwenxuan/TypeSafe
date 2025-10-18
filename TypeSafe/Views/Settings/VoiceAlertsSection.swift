//
//  VoiceAlertsSection.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Voice alerts section for accessibility features (optional, future implementation)
//

import SwiftUI

/// Settings section for voice alerts accessibility feature
/// Provides toggle for enabling spoken scam alerts (future feature)
struct VoiceAlertsSection: View {
    
    // MARK: - Properties
    
    /// Settings manager for voice alerts control
    @ObservedObject var settingsManager: SettingsManager
    
    /// State for showing feature information
    @State private var showingFeatureInfo = false
    
    // MARK: - Body
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.voiceAlertsEnabled },
                    set: { settingsManager.updateVoiceAlertsSetting($0) }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Voice Alerts")
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                // Beta badge
                                Text("COMING SOON")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                            
                            Text("Speak scam alerts aloud")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(true)  // Disabled until feature is implemented
                .opacity(0.6)
                .accessibilityLabel("Voice Alerts (Coming Soon)")
                .accessibilityHint("This feature is not yet available")
                
                // Feature description
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accessibility Feature")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            
                            Text("When enabled, TypeSafe will speak scam alerts aloud using text-to-speech for improved accessibility.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showingFeatureInfo = true }) {
                        Text("Learn more about voice alerts")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.vertical, 8)
            
        } header: {
            Text("Accessibility")
                .font(.headline)
        } footer: {
            Text("Voice alerts will be available in a future update. This feature will use iOS VoiceOver technology to speak alerts.")
                .font(.caption)
        }
        .alert("Voice Alerts Feature", isPresented: $showingFeatureInfo) {
            Button("OK") { }
        } message: {
            Text(voiceAlertsInfoMessage)
        }
    }
    
    // MARK: - Content
    
    /// Detailed voice alerts feature information
    private var voiceAlertsInfoMessage: String {
        """
        Voice Alerts (Coming Soon):
        
        • Spoken notifications for scam alerts
        • Uses iOS VoiceOver technology
        • Customizable voice and speech rate
        • Respects system accessibility settings
        
        This feature is designed to improve accessibility for users with visual impairments or those who prefer auditory alerts.
        
        Expected in a future update.
        """
    }
}

// MARK: - Preview

#Preview {
    Form {
        VoiceAlertsSection(settingsManager: SettingsManager.shared)
    }
}

