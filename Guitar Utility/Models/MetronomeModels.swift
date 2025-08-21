//
//  MetronomeModels.swift
//  Guitar Utility
//
//  Created by sachin kumar on 04/07/25.
//

import Foundation
import Combine

class MetronomeSettings: ObservableObject {
    @Published var bpm: Int = 120
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var subdivision: MetronomeSubdivision = .quarter
    @Published var isRunning: Bool = false
    @Published var currentBeat: Int = 0
    @Published var volume: Double = 0.8
    
    var intervalBetweenBeats: TimeInterval {
        let beatsPerSecond = Double(bpm) / 60.0
        let subdivisionMultiplier = Double(subdivision.subdivisionCount)
        return 1.0 / (beatsPerSecond * subdivisionMultiplier)
    }
    
    func togglePlayback() {
        isRunning.toggle()
        if !isRunning {
            currentBeat = 0
        }
    }
    
    func nextBeat() {
        let totalBeats = timeSignature.beatsPerMeasure * subdivision.subdivisionCount
        currentBeat = (currentBeat + 1) % totalBeats
    }
    
    var isDownbeat: Bool {
        // Every subdivision count marks a main beat
        return currentBeat % subdivision.subdivisionCount == 0
    }
    
    var isAccentedBeat: Bool {
        // Only the very first beat of the measure is accented
        return currentBeat == 0
    }
}

struct TimeSignature: Identifiable, Hashable {
    let id = UUID()
    let numerator: Int
    let denominator: Int
    let name: String
    
    var beatsPerMeasure: Int { numerator }
    
    static let fourFour = TimeSignature(numerator: 4, denominator: 4, name: "4/4")
    static let threeFour = TimeSignature(numerator: 3, denominator: 4, name: "3/4")
    static let twoFour = TimeSignature(numerator: 2, denominator: 4, name: "2/4")
    static let sixEight = TimeSignature(numerator: 6, denominator: 8, name: "6/8")
    static let twelveEight = TimeSignature(numerator: 12, denominator: 8, name: "12/8")
    
    static let allTimeSignatures = [fourFour, threeFour, twoFour, sixEight, twelveEight]
}

enum MetronomeSubdivision: String, CaseIterable, Identifiable {
    case quarter = "Quarter Notes"
    case eighth = "Eighth Notes"
    case triplets = "Triplets"
    case sixteenth = "Sixteenth Notes"
    
    var id: String { rawValue }
    
    var subdivisionCount: Int {
        switch self {
        case .quarter: return 1
        case .eighth: return 2
        case .triplets: return 3
        case .sixteenth: return 4
        }
    }
    
    var iconName: String {
        switch self {
        case .quarter: return "music.note"
        case .eighth: return "music.note.beamed"
        case .triplets: return "music.note.triple"
        case .sixteenth: return "music.note.double.beamed"
        }
    }
}
