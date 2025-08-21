//
//  AudioEngine.swift
//  Guitar Utility
//
//  Created by sachin kumar on 04/07/25.
//

import AVFoundation
import Accelerate
import Combine
import os

enum AudioEngineError: Error {
    case fftSetupFailed
    case audioEngineFailed
}

@MainActor
class AudioEngine: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var fftSetup: FFTSetup?
    private var tapInstalled: Bool = false
    
    @Published var currentFrequency: Double = 0.0
    @Published var isListening: Bool = false
    
    private let sampleRate: Double = 44100.0
    private let bufferSize: Int = 4096
    private let log2BufferSize: vDSP_Length
    
    // Thread-safe data structures
    private let audioQueue = DispatchQueue(label: "audio.processing", qos: .userInteractive)
    private var _frequencyHistory: [Double] = []
    private var _signalStrengthHistory: [Float] = []
    private let historySize = 10
    private let signalHistorySize = 2
    
    // Atomic time tracking
    private let lastProcessTimeLock = OSAllocatedUnfairLock(initialState: Date())
    private let processingInterval: TimeInterval = 0.03
    
    // Thread-safe accessors
    private var frequencyHistory: [Double] {
        get { audioQueue.sync { _frequencyHistory } }
    }
    
    private var signalStrengthHistory: [Float] {
        get { audioQueue.sync { _signalStrengthHistory } }
    }
    
    let permissionManager = PermissionManager()
    
    init() {
        // Validate buffer size is power of 2
        guard bufferSize > 0 && (bufferSize & (bufferSize - 1)) == 0 else {
            fatalError("Buffer size must be a power of 2")
        }
        
        log2BufferSize = vDSP_Length(log2(Float(bufferSize)))
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        
        do {
            try setupAudio()
        } catch {
            print("Failed to setup audio engine: \(error)")
        }
    }
    
    deinit {
        // Ensure all audio processing completes before cleanup
        audioQueue.sync {
            Task { @MainActor in
                await stopListening()
            }
            if let setup = fftSetup {
                vDSP_destroy_fftsetup(setup)
                fftSetup = nil
            }
        }
    }
    
    private func setupAudio() throws {
        // Setup FFT
        guard let setup = vDSP_create_fftsetup(log2BufferSize, FFTRadix(kFFTRadix2)) else {
            throw AudioEngineError.fftSetupFailed
        }
        fftSetup = setup
        
        // Don't install tap here - do it when starting
    }
    
    func startListening() async {
        guard !audioEngine.isRunning else { return }
        
        // For macOS, we need to request permission explicitly first
        await requestMicrophonePermissionAndStart()
    }
    
    private func requestMicrophonePermissionAndStart() async {
        print("🎤 Requesting microphone permission...")
        
        // First check current permission status
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("Current permission status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorized:
            print("✅ Permission already granted")
            await startAudioEngine()
        case .notDetermined:
            print("❓ Permission not determined, requesting...")
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            print("🎯 Permission result: \(granted)")
            if granted {
                await startAudioEngine()
            } else {
                await handlePermissionDenied()
            }
        case .denied, .restricted:
            print("❌ Permission denied/restricted")
            await handlePermissionDenied()
        @unknown default:
            print("❓ Unknown permission status")
            await handlePermissionDenied()
        }
    }
    
    private func handlePermissionDenied() async {
        await MainActor.run {
            self.permissionManager.microphonePermissionStatus = .denied
            self.permissionManager.showingPermissionAlert = true
        }
    }
    
    private func startAudioEngine() async {
        do {
            print("🚀 Starting audio engine...")
            
            // Validate input node has required bus
            guard inputNode.numberOfOutputs > 0 else {
                print("❌ Input node has no output buses")
                throw AudioEngineError.audioEngineFailed
            }
            
            // Configure input node format - use the input node's native format to avoid format conversion crashes
            let inputFormat = inputNode.outputFormat(forBus: 0)
            print("📊 Native input format: \(inputFormat)")
            
            // Validate format has channels
            guard inputFormat.channelCount > 0 else {
                print("❌ Input format has no channels")
                throw AudioEngineError.audioEngineFailed
            }
            
            // Create a compatible format that matches the input format's sample rate and channel count
            // but ensure it's a standard PCM format that we can process
            guard let compatibleFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: inputFormat.channelCount,
                interleaved: false
            ) else {
                print("❌ Failed to create compatible audio format")
                throw AudioEngineError.audioEngineFailed
            }
            
            print("📊 Using compatible format: \(compatibleFormat)")
            
            // Install tap with smaller buffer size for more frequent processing
            let smallerBufferSize = UInt32(1024) // Reduced from 4096 for more frequent callbacks
            inputNode.installTap(onBus: 0, bufferSize: smallerBufferSize, format: compatibleFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            tapInstalled = true
            
            // Prepare and start the audio engine
            try audioEngine.start()
            
            // Update listening state on main thread
            await MainActor.run {
                self.isListening = true
            }
            
            print("✅ Audio engine started successfully!")
            
            // Update permission status after successful start
            await MainActor.run {
                self.permissionManager.microphonePermissionStatus = .granted
            }
            
        } catch let error as NSError {
            print("❌ Failed to start audio engine: \(error)")
            print("❌ Error domain: \(error.domain), code: \(error.code)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] {
                print("❌ Underlying error: \(underlyingError)")
            }
            
            // Clean up on failure
            await cleanupAfterFailure()
            await handlePermissionDenied()
        }
    }
    
    private func cleanupAfterFailure() async {
        await MainActor.run {
            self.isListening = false
        }
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap if it was installed but engine failed to start
        if tapInstalled {
            inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }
    
    func stopListening() async {
        // Stop audio processing first
        if audioEngine.isRunning {
            // Safely remove tap and stop engine
            if tapInstalled {
                inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            audioEngine.stop()
            print("🛑 Audio engine stopped cleanly")
        }
        
        // Update state on main thread
        await MainActor.run {
            self.isListening = false
            self.currentFrequency = 0.0
        }
        
        // Clear history arrays thread-safely
        audioQueue.async { [weak self] in
            self?._frequencyHistory.removeAll()
            self?._signalStrengthHistory.removeAll()
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Validate buffer has channels and data
        guard let floatChannelData = buffer.floatChannelData,
              buffer.format.channelCount > 0,
              let fftSetup = fftSetup else { return }
        
        let channelData = floatChannelData[0]
        
        // Ensure we have valid audio data
        guard buffer.frameLength > 0 else { return }
        
        // Thread-safe time checking
        let now = Date()
        let shouldProcess: Date? = lastProcessTimeLock.withLock { lastTime in
            if now.timeIntervalSince(lastTime) >= processingInterval {
                return now
            }
            return nil
        }
        
        guard let processTime = shouldProcess else { return }
        
        _ = lastProcessTimeLock.withLock { _ in
            processTime
        }
        
        let frameCount = Int(buffer.frameLength)
        
        // Safe memory access with bounds checking
        guard frameCount > 0, frameCount <= bufferSize * 4 else { return } // Safety limit
        
        let samples: [Float]
        do {
            // Create safe copy of audio data
            samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            
            // Validate we actually got the data
            guard samples.count == frameCount else { return }
        }
        
        // Calculate RMS to check signal strength - safe division
        guard samples.count > 0 else { return }
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        
        // Track signal strength history for stability (thread-safe)
        let averageSignalStrength = audioQueue.sync { [weak self] in
            guard let self = self else { return Float(0) }
            self._signalStrengthHistory.append(rms)
            if self._signalStrengthHistory.count > self.signalHistorySize {
                self._signalStrengthHistory.removeFirst()
            }
            
            // Safe division - ensure array is not empty
            guard self._signalStrengthHistory.count > 0 else { return Float(0) }
            return self._signalStrengthHistory.reduce(0, +) / Float(self._signalStrengthHistory.count)
        }
        guard averageSignalStrength > 0.005 else { // Reduced from 0.008 for higher sensitivity
            Task { @MainActor in
                self.currentFrequency = 0.0
            }
            return 
        }
        
        // Pad samples to buffer size if needed
        var paddedSamples = samples
        if paddedSamples.count < bufferSize {
            paddedSamples += Array(repeating: 0.0, count: bufferSize - paddedSamples.count)
        } else if paddedSamples.count > bufferSize {
            paddedSamples = Array(paddedSamples.prefix(bufferSize))
        }
        
        // Apply Hanning window for better frequency resolution
        var windowedSamples = [Float](repeating: 0, count: bufferSize)
        for i in 0..<bufferSize {
            let window = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(bufferSize - 1)))
            windowedSamples[i] = paddedSamples[i] * window
        }
        
        // Perform FFT and detect fundamental frequency
        let frequency = performFFT(on: windowedSamples, setup: fftSetup)
        
        // Filter and smooth (like Guitar Tuna) with faster response
        if frequency > 45.0 && frequency < 180.0 { // Updated range for correct guitar frequencies
            let smoothedFrequency = addToFrequencyHistoryAndGetStable(frequency)
            
            Task { @MainActor in
                self.currentFrequency = smoothedFrequency
            }
        }
    }
    
    private func addToFrequencyHistoryAndGetStable(_ frequency: Double) -> Double {
        return audioQueue.sync {
            _frequencyHistory.append(frequency)
            if _frequencyHistory.count > historySize {
                _frequencyHistory.removeFirst()
            }
            
            // Calculate stable frequency
            guard _frequencyHistory.count >= 1 else { return 0.0 }
            
            // Safe median calculation
            let sortedFrequencies = _frequencyHistory.sorted()
            guard !sortedFrequencies.isEmpty else { return 0.0 }
            
            let median: Double
            if sortedFrequencies.count % 2 == 0 {
                let mid1 = sortedFrequencies[sortedFrequencies.count / 2 - 1]
                let mid2 = sortedFrequencies[sortedFrequencies.count / 2]
                median = (mid1 + mid2) / 2.0
            } else {
                median = sortedFrequencies[sortedFrequencies.count / 2]
            }
            
            let recentFrequencies = Array(_frequencyHistory.suffix(1))
            let allCloseToMedian = recentFrequencies.allSatisfy { abs($0 - median) <= 6.0 }
            
            return allCloseToMedian ? median : 0.0
        }
    }
    
    private func performFFT(on samples: [Float], setup: FFTSetup) -> Double {
        let count = samples.count
        let halfCount = count / 2
        
        var realParts = samples
        var imaginaryParts = [Float](repeating: 0, count: count)
        
        // Validate arrays have correct size
        guard realParts.count == count,
              imaginaryParts.count == count else {
            return 0.0
        }
        
        // Perform forward FFT with proper memory management
        let frequency = realParts.withUnsafeMutableBufferPointer { realPtr in
            imaginaryParts.withUnsafeMutableBufferPointer { imagPtr in
                guard let realBasePtr = realPtr.baseAddress,
                      let imagBasePtr = imagPtr.baseAddress else {
                    return 0.0
                }
                
                var splitComplex = DSPSplitComplex(realp: realBasePtr, imagp: imagBasePtr)
                
                // Perform forward FFT
                vDSP_fft_zrip(setup, &splitComplex, 1, log2BufferSize, FFTDirection(kFFTDirection_Forward))
                
                // Calculate magnitudes with size validation
                var magnitudes = [Float](repeating: 0, count: halfCount)
                guard magnitudes.count == halfCount else { return 0.0 }
                
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfCount))
                
                return findPeakFrequency(magnitudes: magnitudes, sampleRate: sampleRate, bufferSize: count)
            }
        }
        
        return frequency
    }
    
    private func findPeakFrequency(magnitudes: [Float], sampleRate: Double, bufferSize: Int) -> Double {
        let halfCount = magnitudes.count
        
        // Use correct guitar frequency range: 50 Hz (A₁) to 175 Hz (E₃ with tolerance)
        let minFreq = 45.0   // Below lowest guitar frequency (A₁: 55.0 Hz)
        let maxFreq = 180.0  // Above highest frequency (E₃: 164.8 Hz)
        let minIndex = Int(minFreq * Double(bufferSize) / sampleRate)
        let maxIndex = Int(maxFreq * Double(bufferSize) / sampleRate)
        
        // Safe bounds checking
        guard minIndex >= 0, 
              maxIndex < halfCount, 
              minIndex < maxIndex,
              minIndex < magnitudes.count,
              maxIndex <= magnitudes.count else { 
            return 0.0 
        }
        
        // Safe array slicing
        let searchRange = Array(magnitudes[minIndex..<maxIndex])
        guard !searchRange.isEmpty else { return 0.0 }
        
        // Find peak within guitar's range
        var maxValue: Float = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxvi(searchRange, 1, &maxValue, &maxIdx, vDSP_Length(searchRange.count))
        
        let actualMaxIndex = Int(maxIdx) + minIndex
        
        // Apply parabolic interpolation for sub-bin accuracy
        let interpolatedIndex = parabolicInterpolation(magnitudes: magnitudes, peakIndex: actualMaxIndex)
        let frequency = interpolatedIndex * sampleRate / Double(bufferSize)
        
        // Validate frequency is within guitar's range and is finite
        guard frequency >= 45.0 && frequency <= 180.0 && frequency.isFinite else { return 0.0 }
        
        print("🎵 Detected frequency: \(String(format: "%.2f", frequency)) Hz")
        
        return frequency
    }
    
    private func findFundamentalFrequency(magnitudes: [Float], sampleRate: Double, bufferSize: Int) -> Double {
        let halfCount = magnitudes.count
        
        // Strategy 1: Find peak in guitar fundamental range (70-350 Hz)
        let minFreq = 70.0
        let maxFreq = 350.0
        let minIndex = Int(minFreq * Double(bufferSize) / sampleRate)
        let maxIndex = Int(maxFreq * Double(bufferSize) / sampleRate)
        
        guard minIndex >= 0,
              maxIndex < halfCount,
              minIndex < maxIndex,
              minIndex < magnitudes.count,
              maxIndex <= magnitudes.count else { return 0.0 }
        
        // Find the strongest peak in fundamental range
        let searchRange = Array(magnitudes[minIndex..<maxIndex])
        guard !searchRange.isEmpty else { return 0.0 }
        
        var maxValue: Float = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxvi(searchRange, 1, &maxValue, &maxIdx, vDSP_Length(searchRange.count))
        
        let fundamentalIndex = Int(maxIdx) + minIndex
        let fundamentalFreq = Double(fundamentalIndex) * sampleRate / Double(bufferSize)
        
        // Strategy 2: Check for harmonic series to confirm fundamental
        _ = confirmFundamentalWithHarmonics(
            magnitudes: magnitudes,
            candidateFreq: fundamentalFreq,
            sampleRate: sampleRate,
            bufferSize: bufferSize
        )
        
        // Apply parabolic interpolation for sub-bin accuracy
        let interpolatedIndex = parabolicInterpolation(magnitudes: magnitudes, peakIndex: fundamentalIndex)
        let finalFreq = interpolatedIndex * sampleRate / Double(bufferSize)
        
        return finalFreq
    }
    
    private func confirmFundamentalWithHarmonics(magnitudes: [Float], candidateFreq: Double, sampleRate: Double, bufferSize: Int) -> Double {
        // Check if 2nd and 3rd harmonics are present
        let secondHarmonic = candidateFreq * 2
        let thirdHarmonic = candidateFreq * 3
        
        let secondIndex = Int(secondHarmonic * Double(bufferSize) / sampleRate)
        let thirdIndex = Int(thirdHarmonic * Double(bufferSize) / sampleRate)
        
        let fundamentalIndex = Int(candidateFreq * Double(bufferSize) / sampleRate)
        
        guard fundamentalIndex < magnitudes.count,
              secondIndex < magnitudes.count,
              thirdIndex < magnitudes.count else {
            return candidateFreq
        }
        
        let fundamentalMagnitude = magnitudes[fundamentalIndex]
        let secondMagnitude = magnitudes[secondIndex]
        let thirdMagnitude = magnitudes[thirdIndex]
        
        // If harmonics are significantly weaker than fundamental, it's likely correct
        if fundamentalMagnitude > secondMagnitude * 0.5 && fundamentalMagnitude > thirdMagnitude * 0.3 {
            print("✅ Fundamental confirmed by harmonic analysis")
            return candidateFreq
        }
        
        // If 2nd harmonic is stronger, the detected frequency might be the harmonic
        if secondMagnitude > fundamentalMagnitude * 1.5 {
            print("🔄 Detected harmonic, dividing by 2")
            return candidateFreq / 2
        }
        
        return candidateFreq
    }
    
    private func parabolicInterpolation(magnitudes: [Float], peakIndex: Int) -> Double {
        guard peakIndex > 0 && peakIndex < magnitudes.count - 1,
              peakIndex >= 0 && peakIndex < magnitudes.count else {
            return Double(peakIndex)
        }
        
        let y1 = magnitudes[peakIndex - 1]
        let y2 = magnitudes[peakIndex]
        let y3 = magnitudes[peakIndex + 1]
        
        let a = (y1 - 2*y2 + y3) / 2
        let b = (y3 - y1) / 2
        
        guard abs(a) > 1e-8 else { return Double(peakIndex) } // Increased threshold
        
        let xp = -b / (2 * a)
        
        // Clamp interpolation to reasonable bounds
        let clampedXp = max(-1.0, min(1.0, Double(xp)))
        let result = Double(peakIndex) + clampedXp
        
        return result.isFinite ? result : Double(peakIndex)
    }
}

