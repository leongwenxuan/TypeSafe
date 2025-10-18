//
//  DataManagementSection.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Data management section with data deletion controls
//

import SwiftUI

/// Settings section for data management and deletion
/// Provides comprehensive data deletion with confirmation
struct DataManagementSection: View {
    
    // MARK: - Properties
    
    /// Settings manager for data operations
    @ObservedObject var settingsManager: SettingsManager
    
    /// State for showing deletion confirmation dialog
    @State private var showingDeleteConfirmation = false
    
    /// State for showing deletion completion alert
    @State private var showingDeletionComplete = false
    
    /// State for deletion in progress
    @State private var isDeletingData = false
    
    // MARK: - Body
    
    var body: some View {
        Section {
            // Data Retention Information
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data Retention")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("\(settingsManager.settings.dataRetentionDays) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Auto-Delete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Scan history is automatically deleted after \(settingsManager.settings.dataRetentionDays) days to protect your privacy.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            
            // Delete All Data Button
            VStack(spacing: 0) {
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: isDeletingData ? "hourglass" : "trash.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete All Data")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Text("Clear history and reset session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isDeletingData {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disabled(isDeletingData)
                .accessibilityLabel("Delete All Data")
                .accessibilityHint("Permanently deletes all scan history and resets your session")
            }
            
        } header: {
            Text("Data Management")
                .font(.headline)
        } footer: {
            Text("Deleting all data is permanent and cannot be undone. This will clear your scan history, reset your session ID, and remove all app data.")
                .font(.caption)
        }
        .confirmationDialog(
            "Delete All Data",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                performDataDeletion()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(deletionWarningMessage)
        }
        .alert("Data Deleted", isPresented: $showingDeletionComplete) {
            Button("OK") { }
        } message: {
            Text("All your data has been permanently deleted. A new anonymous session has been created.")
        }
    }
    
    // MARK: - Methods
    
    /// Performs complete data deletion
    private func performDataDeletion() {
        isDeletingData = true
        
        // Perform deletion with slight delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = settingsManager.deleteAllUserData()
            
            isDeletingData = false
            
            if success {
                showingDeletionComplete = true
                print("DataManagementSection: Data deletion successful")
            } else {
                print("DataManagementSection: Data deletion failed")
            }
        }
    }
    
    // MARK: - Content
    
    /// Warning message for deletion confirmation
    private var deletionWarningMessage: String {
        """
        This will permanently delete:
        
        • All scan history
        • Your anonymous session ID
        • All app settings and preferences
        • All cached data
        
        This action cannot be undone. Are you sure?
        """
    }
}

// MARK: - Preview

#Preview {
    Form {
        DataManagementSection(settingsManager: SettingsManager.shared)
    }
}

