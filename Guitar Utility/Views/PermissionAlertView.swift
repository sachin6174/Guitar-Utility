//
//  PermissionAlertView.swift
//  Guitar Utility
//
//  Created by sachin kumar on 04/07/25.
//

import SwiftUI

struct PermissionAlertView: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Microphone Access Required")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Guitar Utility needs access to your microphone to detect guitar string frequencies for tuning.\n\nPlease enable microphone access in System Preferences to use the tuner.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Open Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MicrophonePermissionSheet: View {
    @Binding var isPresented: Bool
    let permissionManager: PermissionManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Microphone Permission")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 24) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("Enable Microphone Access")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("The Guitar Tuner needs access to your microphone to detect and analyze guitar string frequencies for accurate tuning.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 16) {
                    Button("Maybe Later") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Open System Preferences") {
                        permissionManager.openSystemPreferences()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 400)
        .background(.regularMaterial)
    }
}

#Preview {
    MicrophonePermissionSheet(
        isPresented: .constant(true),
        permissionManager: PermissionManager()
    )
}
