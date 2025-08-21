import Foundation
import Combine

class MetronomeViewModel: ObservableObject {
    @Published var settings = MetronomeSettings()
    @Published var isPlaying: Bool = false
    @Published var currentBeatNumber: Int = 1
    @Published var lastTapTime: Date?
    
    private let audioEngine = MetronomeAudioEngine()
    private var timer: Timer?
    private var tapTimes: [Date] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        audioEngine.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)
    }
    
    func togglePlayback() {
        if isPlaying {
            stopMetronome()
        } else {
            startMetronome()
        }
    }
    
    private func startMetronome() {
        audioEngine.start()
        settings.isRunning = true
        settings.currentBeat = 0
        currentBeatNumber = 1
        
        timer = Timer.scheduledTimer(withTimeInterval: settings.intervalBetweenBeats, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func stopMetronome() {
        timer?.invalidate()
        timer = nil
        audioEngine.stop()
        settings.isRunning = false
        settings.currentBeat = 0
        currentBeatNumber = 1
    }
    
    private func tick() {
        settings.nextBeat()
        
        let beatInMeasure = (settings.currentBeat / settings.subdivision.subdivisionCount) + 1
        currentBeatNumber = beatInMeasure
        
        // Play sound on every beat - downbeat gets accented sound, others get regular sound
        if settings.isAccentedBeat {
            print("🔊 Playing DOWNBEAT (accented)")
            audioEngine.playDownbeat()
        } else {
            print("🔊 Playing upbeat (regular)")
            audioEngine.playUpbeat()
        }
        
        // Restart timer with current interval
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.intervalBetweenBeats, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func updateBPM(_ newBPM: Int) {
        let clampedBPM = max(40, min(240, newBPM))
        settings.bpm = clampedBPM
        
        if isPlaying {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: settings.intervalBetweenBeats, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }
    }
    
    func updateTimeSignature(_ timeSignature: TimeSignature) {
        settings.timeSignature = timeSignature
        settings.currentBeat = 0
        currentBeatNumber = 1
    }
    
    func updateSubdivision(_ subdivision: MetronomeSubdivision) {
        settings.subdivision = subdivision
        settings.currentBeat = 0
        currentBeatNumber = 1
        
        if isPlaying {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: settings.intervalBetweenBeats, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }
    }
    
    func tapTempo() {
        let now = Date()
        lastTapTime = now
        tapTimes.append(now)
        
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }
        
        guard tapTimes.count >= 2 else { return }
        
        var intervals: [TimeInterval] = []
        for i in 1..<tapTimes.count {
            intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i-1]))
        }
        
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let calculatedBPM = Int(60.0 / averageInterval)
        
        if calculatedBPM >= 40 && calculatedBPM <= 240 {
            updateBPM(calculatedBPM)
        }
        
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 4.0 }
    }
    
    var beatProgress: Double {
        guard settings.timeSignature.beatsPerMeasure > 0 else { return 0 }
        let beatInMeasure = Double(settings.currentBeat) / Double(settings.subdivision.subdivisionCount)
        return beatInMeasure / Double(settings.timeSignature.beatsPerMeasure)
    }
}

