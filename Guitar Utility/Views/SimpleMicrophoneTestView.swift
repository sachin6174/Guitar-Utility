//  SimpleMicrophoneTest.swift
//  Guitar Utility
//
//  Minimal microphone permission test without sandboxing complications
//

import AVFoundation
import SwiftUI
import Combine

class SimpleMicrophoneTest: ObservableObject {
    @Published var status = "Not tested yet"
    @Published var showAlert = false
    
    func testMicrophoneAccess() {
        status = "🔄 Testing microphone access..."
        
        // Method 1: Direct AVCaptureDevice request
        print("📞 Requesting microphone access via AVCaptureDevice...")
        
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                print("🎯 AVCaptureDevice result: \(granted)")
                
                if granted {
                    self?.status = "✅ SUCCESS! Microphone access granted"
                    self?.testActualCapture()
                } else {
                    self?.status = "❌ DENIED: Microphone access denied"
                    self?.showAlert = true
                }
            }
        }
    }
    
    private func testActualCapture() {
        // Method 2: Try to actually create audio engine to confirm
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        
        do {
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
                // Just a test - we don't need to process the audio
                print("📊 Audio buffer received - microphone is working!")
            }
            
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.status = "🎉 COMPLETE SUCCESS! Audio engine started, microphone working!"
            }
            
            // Stop after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.status = "⚠️ Permission granted but audio engine failed: \(error.localizedDescription)"
            }
        }
    }
    
    func checkCurrentStatus() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch authStatus {
        case .authorized:
            status = "✅ Already authorized"
        case .denied:
            status = "❌ Previously denied"
            showAlert = true
        case .restricted:
            status = "🚫 Restricted by system"
        case .notDetermined:
            status = "❓ Not yet determined - ready to request"
        @unknown default:
            status = "❓ Unknown authorization status"
        }
        
        print("🔍 Current authorization status: \(authStatus.rawValue)")
    }
}

struct SimpleMicrophoneTestView: View {
    @StateObject private var test = SimpleMicrophoneTest()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎤 Simple Microphone Test")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(test.status)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button("🎯 Test Microphone Access") {
                    test.testMicrophoneAccess()
                }
                .buttonStyle(.borderedProminent)
                
                Button("🔍 Check Current Status") {
                    test.checkCurrentStatus()
                }
                .buttonStyle(.bordered)
            }
            
            Text("This test will request microphone permission and verify it works. Watch for the system dialog!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
        .alert("Microphone Access Denied", isPresented: $test.showAlert) {
            Button("Open System Preferences") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable microphone access in System Preferences > Privacy & Security > Microphone")
        }
    }
}
