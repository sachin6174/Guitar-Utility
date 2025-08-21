//
//  MetronomeView.swift
//  Guitar Utility
//
//  Created by sachin kumar on 04/07/25.
//

import SwiftUI
import Combine

struct MetronomeView: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @State private var bpmText: String = "120"
    
    init(viewModel: MetronomeViewModel) {
        self.viewModel = viewModel
        _bpmText = State(initialValue: "\(viewModel.settings.bpm)")
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background - same as TunerView
            LinearGradient(
                colors: [
                    Color(.windowBackgroundColor),
                    Color(.windowBackgroundColor).opacity(0.8),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - synced with TunerView style
                headerView
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                
                // Main content - use full space like TunerView
                VStack(spacing: 24) {
                    // Main BPM display
                    mainBPMDisplay
                        .padding(.top, 24)
                    
                    // Visual metronome section
                    visualMetronomeView
                    
                    // Control section
                    controlSection
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            bpmText = "\(viewModel.settings.bpm)"
        }
        .onReceive(viewModel.settings.$bpm) { newBPM in
            bpmText = "\(newBPM)"
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Metronome")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Keep Perfect Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var mainBPMDisplay: some View {
        VStack(spacing: 24) {
            // BPM display with modern card design - reduced height
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .frame(height: 200) // Reduced from 280 to 200
                
                VStack(spacing: 12) { // Reduced spacing from 16 to 12
                    // BPM number with animated effects - smaller font
                    Text("\(viewModel.settings.bpm)")
                        .font(.system(size: 60, weight: .bold, design: .rounded)) // Reduced from 72 to 60
                        .foregroundStyle(
                            LinearGradient(
                                colors: viewModel.isPlaying ? [Color.green, Color.mint] : [Color.primary, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(viewModel.isPlaying ? 1.1 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.isPlaying)
                    
                    // BPM label and info - more compact
                    VStack(spacing: 6) { // Reduced spacing from 8 to 6
                        Text("BPM")
                            .font(.subheadline) // Reduced from .headline
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) { // Reduced spacing from 16 to 12
                            Label("\(viewModel.settings.timeSignature.name)", systemImage: "metronome")
                                .font(.caption) // Reduced from .subheadline
                                .foregroundColor(.secondary)
                            
                            Text("\(viewModel.settings.subdivision.rawValue)")
                                .font(.caption) // Reduced from .subheadline
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Status indicator
                    Text(viewModel.isPlaying ? "Playing" : "Ready to Start")
                        .font(.subheadline) // Reduced from .title3
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.isPlaying ? .green : .secondary)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isPlaying)
                }
                .padding(24) // Reduced from 32 to 24
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    private var visualMetronomeView: some View {
        VStack(spacing: 12) { // Reduced spacing from 16 to 12
            // Section header
            HStack {
                Text("Beats")
                    .font(.subheadline) // Reduced from .headline
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Current beat indicator - more compact
                HStack(spacing: 6) { // Reduced spacing from 8 to 6
                    Image(systemName: "circle.fill")
                        .font(.caption2) // Reduced from .caption
                        .foregroundColor(viewModel.isPlaying ? .green : .secondary)
                    Text("Beat \(viewModel.currentBeatNumber)")
                        .font(.caption2) // Reduced from .caption
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.isPlaying ? .green : .secondary)
                }
                .padding(.horizontal, 10) // Reduced from 12 to 10
                .padding(.vertical, 6) // Reduced from 8 to 6
                .background(
                    (viewModel.isPlaying ? Color.green : Color.secondary).opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            
            // Visual metronome with adaptive height
            MetronomeVisualizer(
                isPlaying: viewModel.isPlaying,
                currentBeat: viewModel.currentBeatNumber,
                totalBeats: viewModel.settings.timeSignature.beatsPerMeasure,
                beatProgress: viewModel.beatProgress
            )
            .frame(height: viewModel.settings.timeSignature.beatsPerMeasure <= 6 ? 80 : 120)
        }
    }
    
    private var controlSection: some View {
        VStack(spacing: 16) {
            // BPM Slider
            VStack(spacing: 10) {
                HStack {
                    Text("Tempo")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(viewModel.settings.bpm) BPM")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.bpm) },
                        set: { viewModel.updateBPM(Int($0)) }
                    ),
                    in: 40...240,
                    step: 1
                )
                .accentColor(.blue)
                
                HStack {
                    Text("40")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("240")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Settings row
            HStack(spacing: 16) {
                // Time Signature Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time Signature")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(TimeSignature.allTimeSignatures) { timeSignature in
                            Button(timeSignature.name) {
                                viewModel.updateTimeSignature(timeSignature)
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.settings.timeSignature.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Subdivision Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subdivision")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(MetronomeSubdivision.allCases) { subdivision in
                            Button(subdivision.rawValue) {
                                viewModel.updateSubdivision(subdivision)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: viewModel.settings.subdivision.iconName)
                                .font(.caption)
                            Text(viewModel.settings.subdivision.rawValue)
                                .font(.caption)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Control buttons row
            HStack(spacing: 16) {
                // Tap Tempo Button
                Button(action: viewModel.tapTempo) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title3)
                        Text("Tap Tempo")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play/Stop Button - same style as tuner
                Button(action: viewModel.togglePlayback) {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(viewModel.isPlaying ? "Stop" : "Start")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: viewModel.isPlaying ? 
                                [Color.red, Color.red.opacity(0.8)] : 
                                [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: (viewModel.isPlaying ? Color.red : Color.green).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct MetronomeVisualizer: View {
    let isPlaying: Bool
    let currentBeat: Int
    let totalBeats: Int
    let beatProgress: Double
    
    @State private var pulseScale: CGFloat = 1.0
    
    private var beatsLayout: (rows: Int, beatsPerRow: Int) {
        if totalBeats <= 6 {
            return (rows: 1, beatsPerRow: totalBeats)
        } else if totalBeats <= 12 {
            let beatsPerRow = (totalBeats + 1) / 2
            return (rows: 2, beatsPerRow: beatsPerRow)
        } else {
            let beatsPerRow = (totalBeats + 2) / 3
            return (rows: 3, beatsPerRow: beatsPerRow)
        }
    }
    
    var body: some View {
        ZStack {
            // Background similar to fretboard
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray),
                            Color(.systemGray).opacity(0.5),
                            Color(.systemGray).opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            
            VStack(spacing: 8) {
                ForEach(0..<beatsLayout.rows, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(1...beatsPerRowForRow(row), id: \.self) { beatInRow in
                            let beat = row * beatsLayout.beatsPerRow + beatInRow
                            if beat <= totalBeats {
                                beatCircle(for: beat)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    private func beatsPerRowForRow(_ row: Int) -> Int {
        let startBeat = row * beatsLayout.beatsPerRow + 1
        let endBeat = min((row + 1) * beatsLayout.beatsPerRow, totalBeats)
        return endBeat - startBeat + 1
    }
    
    private func beatCircle(for beat: Int) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 2)
                .frame(width: 40, height: 40)
            
            Circle()
                .fill(beat == currentBeat && isPlaying ? .blue : .clear)
                .frame(width: 34, height: 34)
                .scaleEffect(beat == currentBeat && isPlaying ? pulseScale : 1.0)
                .animation(.easeInOut(duration: 0.1), value: currentBeat)
            
            Text("\(beat)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(beat == currentBeat && isPlaying ? .white : .primary)
        }
        .onChange(of: isPlaying) { _, playing in
            if !playing {
                pulseScale = 1.0
            }
        }
        .onChange(of: currentBeat) { _, _ in
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.1)) {
                    pulseScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        pulseScale = 1.0
                    }
                }
            }
        }
    }
}

#Preview {
    MetronomeView(viewModel: MetronomeViewModel())
        .frame(width: 500, height: 850)
}
