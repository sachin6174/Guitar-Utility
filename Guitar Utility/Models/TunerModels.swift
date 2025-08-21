//
//  TunerModels.swift
//  Guitar Utility
//
//  Created by sachin kumar on 04/07/25.
//

import Foundation

struct GuitarString: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let frequency: Double
    let stringNumber: Int
    let octave: Int
    
    var displayName: String {
        return "\(name)\(octave)"
    }
    
    var noteWithOctave: String {
        return "\(name)₂\(octave)"
    }
}

struct GuitarTuning: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let strings: [GuitarString]
    
    static let standard = GuitarTuning(
        name: "Standard",
        strings: [
            GuitarString(name: "E", frequency: 82.4079, stringNumber: 1, octave: 2),  // E₂ (thick, low E)
            GuitarString(name: "A", frequency: 55.0000, stringNumber: 2, octave: 1),  // A₁
            GuitarString(name: "D", frequency: 73.4162, stringNumber: 3, octave: 2),  // D₂
            GuitarString(name: "G", frequency: 97.9989, stringNumber: 4, octave: 2),  // G₂
            GuitarString(name: "B", frequency: 123.4708, stringNumber: 5, octave: 2), // B₂
            GuitarString(name: "E", frequency: 164.8141, stringNumber: 6, octave: 3)  // E₃ (thin, high E)
        ]
    )
    
    static let allTunings = [standard]
}

enum TuningAccuracy {
    case tooFlat
    case slightlyFlat
    case inTune
    case slightlySharp
    case tooSharp
    
    var color: String {
        switch self {
        case .tooFlat, .tooSharp:
            return "red"
        case .slightlyFlat, .slightlySharp:
            return "orange"
        case .inTune:
            return "green"
        }
    }
    
    var instruction: String {
        switch self {
        case .tooFlat:
            return "Tighten string significantly"
        case .slightlyFlat:
            return "Tighten string slightly"
        case .inTune:
            return "Perfect! String is in tune"
        case .slightlySharp:
            return "Loosen string slightly"
        case .tooSharp:
            return "Loosen string significantly"
        }
    }
}

struct TuningResult {
    let detectedFrequency: Double
    let targetString: GuitarString?
    let accuracy: TuningAccuracy
    let centOffset: Double // Cents from target frequency
    
    static let silent = TuningResult(
        detectedFrequency: 0,
        targetString: nil,
        accuracy: .inTune,
        centOffset: 0
    )
}
