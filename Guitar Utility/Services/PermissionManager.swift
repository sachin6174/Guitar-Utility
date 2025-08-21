//
//  PermissionManager.swift
//  Guitar Utility
//
//  Created by sachin kumar on 04/07/25.
//

import AVFoundation
import AppKit
import SwiftUI
import Combine

class PermissionManager: ObservableObject {
    @Published var microphonePermissionStatus: PermissionStatus = .notDetermined
    @Published var showingPermissionAlert = false
    
    private var permissionCheckTimer: Timer?
    
    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case restricted
    }
    
    init() {
        checkMicrophonePermission()
        startPermissionMonitoring()
        
        // Listen for app becoming active to refresh permission status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        permissionCheckTimer?.invalidate()
    }
    
    @objc private func appDidBecomeActive() {
        // Refresh permission status when app becomes active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkMicrophonePermission()
        }
    }
    
    private func startPermissionMonitoring() {
        // Check permission status every 2 seconds to catch manual changes
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkMicrophonePermission()
        }
    }
    
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        DispatchQueue.main.async {
            switch status {
            case .authorized:
                self.microphonePermissionStatus = .granted
            case .notDetermined:
                self.microphonePermissionStatus = .notDetermined
            case .denied:
                self.microphonePermissionStatus = .denied
            case .restricted:
                self.microphonePermissionStatus = .restricted
            @unknown default:
                self.microphonePermissionStatus = .denied
            }
        }
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void = { _ in }) {
        print("🎤 Requesting microphone permission via AVCaptureDevice...")
        
        // Use Apple's recommended approach
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                print("🎯 Permission request result: \(granted)")
                
                if granted {
                    print("✅ Microphone access GRANTED")
                    self?.microphonePermissionStatus = .granted
                    completion(true)
                } else {
                    print("❌ Microphone access DENIED")
                    self?.microphonePermissionStatus = .denied
                    self?.showingPermissionAlert = true
                    completion(false)
                }
                
                // Force refresh status after request
                self?.checkMicrophonePermission()
            }
        }
    }
    
    // Apple's recommended async pattern for modern apps
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            
            var isAuthorized = status == .authorized
            
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
                
                DispatchQueue.main.async {
                    self.microphonePermissionStatus = isAuthorized ? .granted : .denied
                }
            }
            
            return isAuthorized
        }
    }
    
    func openSystemPreferences() {
        // Try modern macOS first, then fallback to older versions
        if let url = URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
