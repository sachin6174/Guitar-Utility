import SwiftUI

struct TunerView: View {
    @ObservedObject var viewModel: TunerViewModel
    @State private var showingTuningSelector = false
    @State private var showingPermissionSheet = false
    
    init(viewModel: TunerViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
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
                // Header with glassmorphism effect
                headerView
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                
                // Main content - no ScrollView, use full space
                VStack(spacing: 24) {
                    // Main tuning display
                    mainTuningDisplay
                        .padding(.top, 24)
                    
                    // Guitar fretboard
                    guitarFretboardView
                    
                    // Control section
                    controlSection
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingTuningSelector) {
            modernTuningSelectorSheet
        }
        .sheet(isPresented: $showingPermissionSheet) {
            MicrophonePermissionSheet(
                isPresented: $showingPermissionSheet,
                permissionManager: viewModel.audioEngine.permissionManager
            )
        }
        .onReceive(viewModel.audioEngine.permissionManager.$showingPermissionAlert) { shouldShow in
            showingPermissionSheet = shouldShow
        }
        .onAppear {
            viewModel.audioEngine.permissionManager.checkMicrophonePermission()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Guitar Tuner")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Standard Tuning (E₂-A₁-D₂-G₂-B₂-E₃)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Permission indicator
                if viewModel.audioEngine.permissionManager.microphonePermissionStatus == .denied {
                    Button(action: { showingPermissionSheet = true }) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(.red.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var mainTuningDisplay: some View {
        VStack(spacing: 24) {
            // Note display with modern card design - reduced height
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .frame(height: 200) // Reduced from 280 to 200
                
                VStack(spacing: 10) { // Reduced spacing from 16 to 12
                    if let targetString = viewModel.tuningResult.targetString {
                        // Note name with animated color - even smaller font
                        Text(targetString.displayName)
                            .font(.system(size: 48, weight: .bold, design: .rounded)) // Reduced from 60 to 48
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradientForAccuracy(viewModel.tuningResult.accuracy),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(viewModel.tuningResult.accuracy == .inTune ? 1.1 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.tuningResult.accuracy)
                        
                        // Always show detected frequency prominently - smaller
                        VStack(spacing: 3) { // Reduced spacing from 4 to 3
                            Text("Detected Frequency")
                                .font(.caption2) // Reduced from .caption
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 6) { // Reduced spacing from 8 to 6
                                Text("\(viewModel.audioEngine.currentFrequency, specifier: "%.2f") Hz")
                                    .font(.headline) // Reduced from .title2
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                
                                // Show green tick if frequency is in ±2.5 Hz range
                                if let target = viewModel.tuningResult.targetString,
                                   abs(viewModel.audioEngine.currentFrequency - target.frequency) <= 2.5 &&
                                   viewModel.audioEngine.currentFrequency > 0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline) // Reduced from .title2
                                        .foregroundColor(.green)
                                        .scaleEffect(1.1) // Reduced from 1.2
                                        .animation(.easeInOut(duration: 0.3), value: viewModel.tuningResult.accuracy)
                                }
                            }
                        }
                        
                        // String info with octave - more compact
                        HStack(spacing: 10) { // Reduced spacing from 12 to 10
                            Label("\(targetString.noteWithOctave) String", systemImage: "guitars")
                                .font(.caption) // Reduced from .subheadline
                                .foregroundColor(.secondary)
                            
                            Text("Target: \(targetString.frequency, specifier: "%.1f") Hz")
                                .font(.caption.monospacedDigit()) // Reduced from .subheadline
                                .foregroundColor(.secondary)
                        }
                        
                        // Range indicator - smaller
                        VStack(spacing: 3) { // Reduced spacing from 4 to 3
                            let inRange = abs(viewModel.audioEngine.currentFrequency - targetString.frequency) <= 2.5
                            Text(inRange ? "✅ WITHIN ±2.5 Hz RANGE" : "📍 Target Range: ±2.5 Hz")
                                .font(.caption2) // Reduced from .caption
                                .fontWeight(.semibold)
                                .foregroundColor(inRange ? .green : .secondary)
                                .padding(.horizontal, 10) // Reduced from 12 to 10
                                .padding(.vertical, 3) // Reduced from 4 to 3
                                .background(
                                    RoundedRectangle(cornerRadius: 6) // Reduced from 8 to 6
                                        .fill(inRange ? Color.green.opacity(0.1) : Color.clear)
                                )
                        }
                        
                        // Show completion message when all strings are tuned
                        if viewModel.allStringsTuned {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                Text("🎉 Guitar Perfectly Tuned!")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .scaleEffect(1.05)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.allStringsTuned)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Accuracy indicator - smaller
                        Text(viewModel.tuningInstructions)
                            .font(.caption) // Reduced from .subheadline
                            .fontWeight(.semibold)
                            .foregroundColor(colorForAccuracy(viewModel.tuningResult.accuracy))
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.tuningInstructions)
                        
                    } else {
                        VStack(spacing: 8) { // Reduced spacing from 10 to 8
                            Image(systemName: viewModel.isListening ? "waveform" : "tuningfork")
                                .font(.system(size: 32)) // Reduced from 40 to 32
                                .foregroundColor(.secondary)
                                .scaleEffect(viewModel.isListening ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isListening)
                            
                            Text(viewModel.isListening ? "Listening..." : "Ready to Tune")
                                .font(.subheadline) // Reduced from .headline
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            // Always show detected frequency when listening - smaller
                            VStack(spacing: 3) { // Reduced spacing from 4 to 3
                                Text("Detected Frequency")
                                    .font(.caption2) // Reduced from .caption
                                    .foregroundColor(.secondary)
                                
                                Text("\(viewModel.audioEngine.currentFrequency, specifier: "%.2f") Hz")
                                    .font(.headline) // Reduced from .title2
                                    .foregroundColor(viewModel.audioEngine.currentFrequency > 0 ? .blue : .secondary.opacity(0.6))
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                            }
                            
                            if viewModel.isListening {
                                // Detection details when listening - more compact
                                VStack(spacing: 4) { // Reduced spacing from 6 to 4
                                    if viewModel.audioEngine.currentFrequency > 0 {
                                        // Show string details if detected with octave
                                        if viewModel.tuningResult.detectedFrequency > 0 {
                                            HStack(spacing: 8) { // Reduced spacing from 10 to 8
                                                Text("→ \(viewModel.tuningResult.targetString?.displayName ?? "?") String")
                                                    .font(.caption2) // Reduced from .caption
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                
                                                Text("Target: \(viewModel.tuningResult.targetString?.frequency ?? 0, specifier: "%.1f") Hz")
                                                    .font(.caption2.monospacedDigit()) // Reduced from .caption
                                                    .foregroundColor(.secondary)
                                            }
                                        } else {
                                            Text("Analyzing frequency...")
                                                .font(.caption2) // Reduced from .caption
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("Play a string on your guitar")
                                            .font(.caption2)
                                            .foregroundColor(.secondary.opacity(0.8))
                                    }
                                    
                                    // Show detection mode - more compact
                                    HStack(spacing: 2) { // Reduced spacing from 3 to 2
                                        Image(systemName: viewModel.manualStringSelection ? "hand.point.up" : "waveform.path.ecg")
                                            .font(.caption2)
                                        Text(viewModel.manualStringSelection ? "Manual Mode" : "Auto-detecting")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8) // Reduced from 10 to 8
                                    .padding(.vertical, 2) // Reduced from 3 to 2
                                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4)) // Reduced from 6 to 4
                                }
                            } else {
                                Text("Press the button below to start")
                                    .font(.caption2) // Reduced from .caption
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxHeight: .infinity) // Fill available space in fixed container
                    }
                }
                .padding(20) // Reduced from 24 to 20
                .frame(maxHeight: .infinity) // Ensure content fills the fixed height
            }
        }
    }
    
    private var guitarFretboardView: some View {
        VStack(spacing: 16) {
            // Mode selector
            HStack {
                Text("String Selection")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Small reset button
                    Button(action: viewModel.resetAllStringStates) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .overlay(
                                Circle()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .buttonStyle(PlainButtonStyle())
                    .help("Reset all string states")
                    
                    // Manual/Auto toggle button
                    Button(action: viewModel.toggleAutoDetection) {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.manualStringSelection ? "hand.point.up.fill" : "waveform.path.ecg")
                                .font(.caption)
                            Text(viewModel.currentModeDescription)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(viewModel.manualStringSelection ? .blue : .green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            (viewModel.manualStringSelection ? Color.blue : Color.green).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke((viewModel.manualStringSelection ? Color.blue : Color.green).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Modern guitar fretboard
            ModernGuitarFretboard(
                strings: viewModel.currentTuning.strings,
                selectedString: viewModel.selectedString,
                manualSelection: viewModel.manualStringSelection,
                stringAccuracyStates: viewModel.stringAccuracyStates,
                onStringSelected: { string in
                    viewModel.selectString(string)
                }
            )
        }
    }
    
    private var controlSection: some View {
        VStack(spacing: 12) {
            // Main tuning button (removed the reset button from here since it's now in the header)
            Button(action: {
                if viewModel.isListening {
                    viewModel.stopTuning()
                } else {
                    viewModel.startTuning()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(viewModel.isListening ? "Stop Tuning" : "Start Tuning")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: viewModel.isListening ? 
                            [Color.red, Color.red.opacity(0.8)] : 
                            [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (viewModel.isListening ? Color.red : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var modernTuningSelectorSheet: some View {
        NavigationView {
            ZStack {
                Color(.windowBackgroundColor)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(GuitarTuning.allTunings) { tuning in
                            Button(action: { 
                                viewModel.changeTuning(to: tuning)
                                showingTuningSelector = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(tuning.name)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Text(tuning.strings.map { $0.name }.joined(separator: " • "))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if tuning.id == viewModel.currentTuning.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(tuning.id == viewModel.currentTuning.id ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Guitar Tunings")
        }
        .frame(width: 500, height: 400)
    }
    
    // Helper functions
    private func colorForAccuracy(_ accuracy: TuningAccuracy) -> Color {
        switch accuracy {
        case .tooFlat, .tooSharp: return Color.red
        case .slightlyFlat, .slightlySharp: return Color.orange
        case .inTune: return Color.green
        }
    }
    
    private func gradientForAccuracy(_ accuracy: TuningAccuracy) -> [Color] {
        switch accuracy {
        case .tooFlat, .tooSharp: 
            return [Color.red, Color.red.opacity(0.7)]
        case .slightlyFlat, .slightlySharp: 
            return [Color.orange, Color.yellow]
        case .inTune: 
            return [Color.green, Color.mint]
        }
    }
}

struct ModernGuitarFretboard: View {
    let strings: [GuitarString]
    let selectedString: GuitarString?
    let manualSelection: Bool
    let stringAccuracyStates: [Int: TuningAccuracy]
    let onStringSelected: (GuitarString) -> Void
    
    var body: some View {
        ZStack {
            // Fretboard background with wood texture effect
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBrown),
                            Color(.systemBrown).opacity(0.5),
                            Color(.systemBrown).opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .frame(height: 160)
            
            // Fret lines
            HStack(spacing: 0) {
                ForEach(0..<8) { fret in
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1)
                    
                    if fret < 7 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 30)
            
            // Guitar strings with modern design
            VStack(spacing: 0) {
                ForEach(strings.sorted(by: { $0.stringNumber > $1.stringNumber })) { string in
                    HStack(spacing: 16) {
                        // String info with octave display
                        VStack(spacing: 4) {
                            Text(string.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(selectedString?.id == string.id ? .blue : .primary)
                        }
                        .frame(width: 40)
                        
                        // String line with modern effects
                        HStack(spacing: 12) {
                            // Tuning status indicator
                            ZStack {
                                Circle()
                                    .fill(getStringColor(for: string.stringNumber))
                                    .frame(width: 32, height: 32)
                                    .shadow(color: getStringColor(for: string.stringNumber).opacity(0.3), radius: 4)
                                
                                if getStringAccuracy(for: string.stringNumber) == .inTune {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .scaleEffect(1.2)
                                        .scaleEffect(getStringAccuracy(for: string.stringNumber) == .inTune ? 1.3 : 1.2)
                                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: getStringAccuracy(for: string.stringNumber))
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            // Modern string line
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: getStringGradient(for: string.stringNumber),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: getStringThickness(for: string.stringNumber))
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedString?.id == string.id ? Color.blue : Color.clear,
                                            lineWidth: 3
                                        )
                                        .shadow(color: Color.blue.opacity(0.3), radius: 4)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        
                        // Frequency
                        Text("\(string.frequency, specifier: "%.0f")Hz")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .frame(height: 20)
                    .onTapGesture {
                        if manualSelection {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                onStringSelected(string)
                            }
                        }
                    }
                    .scaleEffect(selectedString?.id == string.id ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedString?.id)
                    
                    if string.stringNumber > 1 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .overlay(
            Group {
                if !manualSelection {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                        Text("Auto-detecting...")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.green.opacity(0.3), radius: 4)
                    .offset(y: -20)
                }
            },
            alignment: .top
        )
    }
    
    // Helper functions
    private func getStringThickness(for stringNumber: Int) -> CGFloat {
        switch stringNumber {
        case 1: return 6.0
        case 2: return 5.0
        case 3: return 4.0
        case 4: return 3.5
        case 5: return 3.0
        case 6: return 2.5
        default: return 3.0
        }
    }
    
    private func getStringColor(for stringNumber: Int) -> Color {
        let accuracy = getStringAccuracy(for: stringNumber)
        
        switch accuracy {
        case .inTune: return Color.green
        case .slightlyFlat, .slightlySharp: return Color.orange
        case .tooFlat, .tooSharp: return Color.red
        }
    }
    
    private func getStringGradient(for stringNumber: Int) -> [Color] {
        let accuracy = getStringAccuracy(for: stringNumber)
        let isSelected = selectedString?.stringNumber == stringNumber
        
        if isSelected {
            return [Color.blue.opacity(0.8), Color.blue.opacity(0.4)]
        }
        
        switch accuracy {
        case .inTune:
            return [Color.green.opacity(0.8), Color.green.opacity(0.4)]
        case .slightlyFlat, .slightlySharp:
            return [Color.orange.opacity(0.8), Color.orange.opacity(0.4)]
        case .tooFlat, .tooSharp:
            return [Color.red.opacity(0.8), Color.red.opacity(0.4)]
        }
    }
    
    private func getStringAccuracy(for stringNumber: Int) -> TuningAccuracy {
        return stringAccuracyStates[stringNumber] ?? .tooFlat
    }
}

#Preview {
    TunerView(viewModel: TunerViewModel())
        .frame(width: 500, height: 800) // Updated to match new window size
}
