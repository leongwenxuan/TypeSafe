//
//  ImagePreviewView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import SwiftUI

/// Reusable image preview component for displaying selected images
struct ImagePreviewView: View {
    let image: UIImage
    let onUseImage: () -> Void
    let onChooseDifferent: () -> Void
    
    var body: some View {
        ZStack {
            // Ensure proper background color
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Image preview with proper scaling
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .accessibilityLabel("Selected image preview")
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: onUseImage) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Use This Image")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Use this image for scanning")
                .accessibilityHint("Proceed with scanning the selected image")
                
                Button(action: onChooseDifferent) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Choose Different")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .accessibilityLabel("Choose a different image")
                .accessibilityHint("Go back to select a different image")
            }
            }
        }
        .padding()
    }
}

#Preview {
    ImagePreviewView(
        image: UIImage(systemName: "photo") ?? UIImage(),
        onUseImage: { print("Use image") },
        onChooseDifferent: { print("Choose different") }
    )
}
