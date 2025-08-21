import Foundation
import Combine

@MainActor
class TunerViewModel: ObservableObject {
    @Published var currentTuning: GuitarTuning = .standard
    @Published var tuningResult: TuningResult = .silent
    @Published var isListening: Bool = false
    @Published var selectedString: GuitarString?
    @Published var manualStringSelection: Bool = false
    @Published var stringAccuracyStates: [Int: TuningAccuracy] = [:]
    
    let audioEngine = AudioEngine()
    private var cancellables = Set<AnyCancellable>()
    
    private let semitoneRatio = pow(2.0, 1.0/12.0)
    
    // Guitar Tuna-like stability variables with increased sensitivity
    private var stableFrequency: Double = 0.0
    private var frequencyStabilityCount: Int = 0
    private let requiredStabilityCount = 2 // Reduced from 5 for much faster response
    private let frequencyToleranceForStability: Double = 3.0 // Changed from 1.5 to 3.0 for wider tolerance (±3.0)
    private var lastUpdateTime: Date = Date()
    private let minimumUpdateInterval: TimeInterval = 0.05 // Reduced from 0.2 for much faster updates
    
    init() {
        setupBindings()
        initializeStringStates()
    }
    
    private func initializeStringStates() {
        for string in currentTuning.strings {
            stringAccuracyStates[string.stringNumber] = .tooFlat
        }
    }
    
    private func setupBindings() {
        audioEngine.$currentFrequency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frequency in
                self?.processFrequencyWithStability(frequency)
            }
            .store(in: &cancellables)
        
        audioEngine.$isListening
            .receive(on: DispatchQueue.main)
            .assign(to: \.isListening, on: self)
            .store(in: &cancellables)
    }
    
    func startTuning() {
        Task {
            await audioEngine.startListening()
        }
        resetStability()
    }
    
    func stopTuning() {
        Task {
            await audioEngine.stopListening()
        }
        tuningResult = .silent
        if !manualStringSelection {
            selectedString = nil
        }
        resetStability()
    }
    
    func changeTuning(to newTuning: GuitarTuning) {
        currentTuning = newTuning
        initializeStringStates()
        if manualStringSelection {
            selectedString = newTuning.strings.first
        }
        resetStability()
    }
    
    func selectString(_ string: GuitarString) {
        selectedString = string
        manualStringSelection = true
        resetStability()
        print("🎯 Selected: \(string.name) (String \(string.stringNumber)) - \(string.frequency) Hz")
    }
    
    func toggleAutoDetection() {
        manualStringSelection.toggle()
        if !manualStringSelection {
            selectedString = nil
            print("🔄 Auto detection enabled")
        } else {
            selectedString = currentTuning.strings.first
            print("🎯 Manual selection enabled")
        }
        resetStability()
    }
    
    private func resetStability() {
        stableFrequency = 0.0
        frequencyStabilityCount = 0
        lastUpdateTime = Date().addingTimeInterval(-1)
    }
    
    private func processFrequencyWithStability(_ frequency: Double) {
        guard frequency > 30.0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if self.audioEngine.currentFrequency <= 30.0 {
                    self.tuningResult = .silent
                    if !self.manualStringSelection {
                        self.selectedString = nil
                    }
                    self.resetStability()
                }
            }
            return
        }
        
        // Check if frequency is stable (similar to previous reading)
        let isStable = abs(frequency - stableFrequency) <= frequencyToleranceForStability
        
        if isStable {
            frequencyStabilityCount += 1
        } else {
            // New frequency detected, reset stability counter
            stableFrequency = frequency
            frequencyStabilityCount = 1
        }
        
        // Only update UI if we have stable readings AND enough time has passed (like Guitar Tuna)
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateTime)
        
        if frequencyStabilityCount >= requiredStabilityCount && timeSinceLastUpdate >= minimumUpdateInterval {
            processStableFrequency(stableFrequency)
            lastUpdateTime = Date()
        }
    }
    
    private func determineAccuracy(centOffset: Double) -> TuningAccuracy {
        let absCentOffset = abs(centOffset)
        
        if absCentOffset <= 5.0 {  // Very close - green tick
            return .inTune
        } else if absCentOffset <= 15.0 {  // Slightly off
            return centOffset > 0 ? .slightlySharp : .slightlyFlat
        } else {
            return centOffset > 0 ? .tooSharp : .tooFlat
        }
    }
    
    private func isFrequencyInRange(_ frequency: Double, for targetString: GuitarString) -> Bool {
        // Check if frequency is within ±2.5 Hz of target
        let tolerance = 2.5
        return abs(frequency - targetString.frequency) <= tolerance
    }
    
    private func processStableFrequency(_ frequency: Double) {
        let targetString: GuitarString
        
        if manualStringSelection, let manuallySelected = selectedString {
            targetString = manuallySelected
            print("🎯 Using manually selected: String \(targetString.stringNumber) (\(targetString.name)) - \(targetString.frequency) Hz")
        } else {
            guard let detected = findStringInRange(frequency: frequency) else {
                return // Don't update if no clear match (like Guitar Tuna)
            }
            targetString = detected
            selectedString = targetString
            print("🔍 Auto-detected: String \(targetString.stringNumber) (\(targetString.name)) - \(targetString.frequency) Hz")
        }
        
        let centOffset = calculateCentOffset(detected: frequency, target: targetString.frequency)
        var accuracy = determineAccuracy(centOffset: centOffset)
        
        // Special check: if frequency is within ±2.5 Hz range, force green tick
        if isFrequencyInRange(frequency, for: targetString) {
            accuracy = .inTune
            print("✅ Frequency \(frequency) Hz is within ±2.5 Hz range for \(targetString.name)")
        }
        
        // Update string accuracy state for visual feedback
        stringAccuracyStates[targetString.stringNumber] = accuracy
        
        // Only update if the reading is significant (like Guitar Tuna's behavior)
        tuningResult = TuningResult(
            detectedFrequency: frequency,
            targetString: targetString,
            accuracy: accuracy,
            centOffset: centOffset
        )
        
        print("📊 \(targetString.name) (\(String(format: "%.1f", frequency)) Hz): \(accuracy) (\(String(format: "%.1f", centOffset)) cents)")
    }
    
    private func findStringInRange(frequency: Double) -> GuitarString? {
        // Exact frequency ranges for standard guitar tuning with ±2.5 Hz tolerance
        let stringRanges: [(stringNumber: Int, name: String, octave: Int, targetFreq: Double, lower: Double, upper: Double)] = [
            (1, "E", 2, 82.4079, 79.9079, 84.9079),   // E₂ string - low E
            (2, "A", 1, 55.0000, 52.5000, 57.5000),   // A₁ string
            (3, "D", 2, 73.4162, 70.9162, 75.9162),   // D₂ string
            (4, "G", 2, 97.9989, 95.4989, 100.4989),  // G₂ string
            (5, "B", 2, 123.4708, 120.9708, 125.9708), // B₂ string
            (6, "E", 3, 164.8141, 162.3141, 167.3141)  // E₃ string - high E
        ]
        
        for range in stringRanges {
            if frequency >= range.lower && frequency <= range.upper {
                return currentTuning.strings.first { $0.stringNumber == range.stringNumber }
            }
        }
        
        // If no exact match, only return closest if it's reasonably close (within 15 Hz)
        let closest = findClosestString(to: frequency)
        let difference = abs(frequency - closest.frequency)
        
        return difference <= 15.0 ? closest : nil // Reduced tolerance for fallback
    }
    
    private func findClosestString(to frequency: Double) -> GuitarString {
        return currentTuning.strings.min { string1, string2 in
            let diff1 = abs(1200.0 * log2(frequency / string1.frequency))
            let diff2 = abs(1200.0 * log2(frequency / string2.frequency))
            return diff1 < diff2
        } ?? currentTuning.strings[0]
    }
    
    private func calculateCentOffset(detected: Double, target: Double) -> Double {
        return 1200.0 * log2(detected / target)
    }
    
    var needlePosition: Double {
        let maxCents = 50.0
        let clampedOffset = max(-maxCents, min(maxCents, tuningResult.centOffset))
        return clampedOffset / maxCents
    }
    
    var tuningInstructions: String {
        return tuningResult.accuracy.instruction
    }
    
    var currentModeDescription: String {
        return manualStringSelection ? "Manual" : "Auto"
    }
    
    var allStringsTuned: Bool {
        return stringAccuracyStates.values.allSatisfy { $0 == .inTune } && 
               stringAccuracyStates.count == currentTuning.strings.count
    }
    
    func resetAllStringStates() {
        stringAccuracyStates.removeAll()
        initializeStringStates()
        print("🔄 Reset all string tuning states - ready for new guitar")
    }
}

