//
//  MicrophonePermissionTest.swift
//  Guitar Utility
//
//  Simple utility to force microphone permission request
//

import AVFoundation
import SwiftUI
import Combine

class MicrophonePermissionTest: ObservableObject {
    @Published var permissionStatus: String = "Unknown"
    @Published var showDialog = false
    
    func forcePermissionRequest() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🔍 Current authorization status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            permissionStatus = "✅ Already Authorized"
        case .notDetermined:
            permissionStatus = "⏳ Requesting Permission..."
            print("📞 Calling AVCaptureDevice.requestAccess...")
            
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                print("🎯 Permission callback received: \(granted)")
                DispatchQueue.main.async {
                    if granted {
                        self?.permissionStatus = "✅ Permission Granted!"
                        print("✅ SUCCESS: Permission granted, app should appear in System Preferences")
                    } else {
                        self?.permissionStatus = "❌ Permission Denied - Check if dialog appeared"
                        print("❌ DENIED: User clicked 'Don't Allow' or dialog didn't appear")
                        
                        // Check if we can open System Preferences to help user
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self?.showDialog = true
                        }
                    }
                }
            }
        case .denied:
            permissionStatus = "❌ Permission Previously Denied"
            print("❌ Permission was previously denied, opening System Preferences")
            showDialog = true
        case .restricted:
            permissionStatus = "🚫 Permission Restricted by System"
            print("🚫 Permission is restricted (parental controls, etc.)")
        @unknown default:
            permissionStatus = "❓ Unknown Permission Status"
            print("❓ Unknown authorization status: \(status.rawValue)")
        }
    }
    
    func checkStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        permissionStatus = "Status: \(status.rawValue)"
    }
}

struct MicrophonePermissionTestView: View {
    @StateObject private var permissionTest = MicrophonePermissionTest()
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎤 Microphone Permission Test")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(permissionTest.permissionStatus)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(spacing: 12) {
                Button("🎯 Request Microphone Permission") {
                    permissionTest.forcePermissionRequest()
                }
                .buttonStyle(.borderedProminent)
                
                Button("🔍 Check Current Status") {
                    permissionTest.checkStatus()
                }
                .buttonStyle(.bordered)
                
                Button("🔄 Reset All Microphone Permissions") {
                    showingResetAlert = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Instructions:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("1. Click 'Request Microphone Permission'")
                Text("2. System dialog should appear")
                Text("3. Click 'Allow' when prompted")
                Text("4. Check System Preferences > Privacy > Microphone")
                Text("5. 'Guitar Utility' should be listed")
            }
            .font(.caption)
            .multilineTextAlignment(.leading)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            if permissionTest.permissionStatus.contains("Denied") {
                Text("⚠️ If no dialog appeared, the app may need to be reset or rebuilt")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .alert("Reset Microphone Permissions", isPresented: $showingResetAlert) {
            Button("Reset All Apps", role: .destructive) {
                resetMicrophonePermissions()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset microphone permissions for ALL apps. You'll need to re-grant permission to all apps that use the microphone.")
        }
        .alert("Permission Denied", isPresented: $permissionTest.showDialog) {
            Button("Open System Preferences") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone access in System Preferences > Privacy > Microphone")
        }
    }
    
    private func resetMicrophonePermissions() {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["tccutil", "reset", "Microphone"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            DispatchQueue.main.async {
                permissionTest.permissionStatus = "🔄 Permissions reset. Try requesting again."
            }
        } catch {
            print("Failed to reset permissions: \(error)")
            DispatchQueue.main.async {
                permissionTest.permissionStatus = "❌ Reset failed. Run 'sudo tccutil reset Microphone' in Terminal"
            }
        }
    }
}
