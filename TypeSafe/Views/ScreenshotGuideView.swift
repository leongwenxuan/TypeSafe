//
//  ScreenshotGuideView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import SwiftUI

/// Guide view explaining how to take screenshots on iOS
struct ScreenshotGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .accessibilityLabel("Screenshot icon")
                        
                        Text("How to Take a Screenshot")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 20) {
                        GuideStepView(
                            stepNumber: 1,
                            title: "Navigate to Content",
                            description: "Go to the app, message, or webpage you want to scan for potential scams."
                        )
                        
                        GuideStepView(
                            stepNumber: 2,
                            title: "Take Screenshot",
                            description: "Press and hold the Side Button (Power) and Volume Up button at the same time, then quickly release both buttons."
                        )
                        
                        GuideStepView(
                            stepNumber: 3,
                            title: "Return to TypeSafe",
                            description: "Come back to this app and tap 'Select from Photos' to choose your screenshot."
                        )
                        
                        GuideStepView(
                            stepNumber: 4,
                            title: "Select & Scan",
                            description: "Choose your screenshot from the photo picker and tap 'Use This Image' to analyze it for potential threats."
                        )
                    }
                    
                    // Device-specific note
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device Notes")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("• On older iPhones with Home button: Press Home + Side Button")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("• Screenshots are automatically saved to your Photos app")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("• You'll see a thumbnail in the corner after taking a screenshot")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Action button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Got It!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Close screenshot guide")
                    .accessibilityHint("Return to the scan screen")
                }
                .padding()
            }
            .navigationTitle("Screenshot Guide")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close guide")
                }
            }
        }
    }
}

/// Individual step in the screenshot guide
struct GuideStepView: View {
    let stepNumber: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text("\(stepNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Step \(stepNumber)")
            
            // Step content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ScreenshotGuideView()
}
