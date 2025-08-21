//
//  MetronomeAudioEngine.swift
//  Guitar Utility
//
//  Created by sachin kumar on 04/07/25.
//

import AVFoundation
import Combine

class MetronomeAudioEngine: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var mixer: AVAudioMixerNode
    private var format: AVAudioFormat?
    
    private var downbeatBuffer: AVAudioPCMBuffer?
    private var upbeatBuffer: AVAudioPCMBuffer?
    
    @Published var isPlaying: Bool = false
    
    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixer = audioEngine.mainMixerNode
        
        do {
            try setupAudio()
            generateClickSounds()
        } catch {
            print("❌ Failed to setup metronome audio engine: \(error)")
        }
    }
    
    private func setupAudio() throws {
        // Get the output format from the mixer to match channel count
        let outputFormat = mixer.outputFormat(forBus: 0)
        
        // Create format that matches the mixer's output format
        guard let matchingFormat = AVAudioFormat(
            standardFormatWithSampleRate: outputFormat.sampleRate, 
            channels: outputFormat.channelCount
        ) else {
            throw NSError(domain: "MetronomeAudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create matching audio format"])
        }
        
        self.format = matchingFormat
        
        // Attach and connect player node with matching format
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: mixer, format: matchingFormat)
        
        // Configure audio session for playback (macOS equivalent)
        try audioEngine.start()
        print("✅ Metronome audio engine started with format: \(matchingFormat)")
    }
    
    private func generateClickSounds() {
        guard let format = self.format else {
            print("❌ No audio format available")
            return
        }
        
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let duration = 0.1
        let frameCount = Int(sampleRate * duration)
        
        print("🔧 Generating sounds with format: \(channelCount) channels, \(sampleRate) Hz")
        
        // Generate downbeat sound (higher pitch, more prominent)
        downbeatBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(frameCount))
        downbeatBuffer?.frameLength = UInt32(frameCount)
        
        if let buffer = downbeatBuffer {
            generateToneInBuffer(buffer, frequency: 1000.0, sampleRate: sampleRate)
            print("✅ Generated downbeat sound")
        }
        
        // Generate upbeat sound (lower pitch)
        upbeatBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(frameCount))
        upbeatBuffer?.frameLength = UInt32(frameCount)
        
        if let buffer = upbeatBuffer {
            generateToneInBuffer(buffer, frequency: 800.0, sampleRate: sampleRate)
            print("✅ Generated upbeat sound")
        }
    }
    
    private func generateToneInBuffer(_ buffer: AVAudioPCMBuffer, frequency: Double, sampleRate: Double) {
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let amplitude: Float = 0.3
        let omega = 2.0 * Double.pi * frequency / sampleRate
        
        // Generate the same tone for all channels
        for channel in 0..<channelCount {
            guard let channelData = buffer.floatChannelData?[channel] else { continue }
            
            for i in 0..<frameCount {
                let phase = omega * Double(i)
                let normalizedTime = Double(i) / Double(frameCount)
                
                // Improved envelope - quick attack, exponential decay
                let envelope: Float
                if normalizedTime < 0.05 {
                    envelope = Float(normalizedTime / 0.05)
                } else {
                    envelope = Float(exp(-8.0 * (normalizedTime - 0.05)))
                }
                
                channelData[i] = amplitude * envelope * sin(Float(phase))
            }
        }
    }
    
    func playDownbeat() {
        guard let buffer = downbeatBuffer else {
            print("❌ No downbeat buffer")
            return
        }
        print("🔊 Playing downbeat")
        playBuffer(buffer)
    }
    
    func playUpbeat() {
        guard let buffer = upbeatBuffer else {
            print("❌ No upbeat buffer")
            return
        }
        print("🔊 Playing upbeat")
        playBuffer(buffer)
    }
    
    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        if !audioEngine.isRunning {
            print("❌ Audio engine not running, attempting to restart...")
            do {
                try audioEngine.start()
                print("✅ Audio engine restarted successfully")
            } catch {
                print("❌ Failed to restart audio engine: \(error)")
                return
            }
        }
        
        // Verify buffer format matches expected format
        guard let expectedFormat = format,
              buffer.format.channelCount == expectedFormat.channelCount,
              buffer.format.sampleRate == expectedFormat.sampleRate else {
            print("❌ Buffer format mismatch!")
            print("Expected: \(format?.channelCount ?? 0) channels, \(format?.sampleRate ?? 0) Hz")
            print("Got: \(buffer.format.channelCount) channels, \(buffer.format.sampleRate) Hz")
            return
        }
        
        // Stop any currently playing audio to avoid overlapping
        if playerNode.isPlaying {
            playerNode.stop()
        }
        
        // Make sure player node is ready
        if !playerNode.isPlaying {
            playerNode.play()
        }
        
        // Schedule and play the buffer
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        print("✅ Scheduled buffer successfully")
    }
    
    func start() {
        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
                print("✅ Metronome audio engine started")
            }
            if !playerNode.isPlaying {
                playerNode.play()
            }
            isPlaying = true
            print("✅ Metronome started playing")
        } catch {
            print("❌ Failed to start metronome audio engine: \(error)")
        }
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        print("🛑 Metronome stopped")
    }
}
