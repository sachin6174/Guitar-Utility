# 🎸 Guitar Utility

A comprehensive macOS application designed for guitarists, featuring both a precision tuner and professional metronome in one sleek package.

## Features

### 🎵 Guitar Tuner
- **Precise frequency detection** using advanced FFT analysis
- **Standard tuning support** (E-A-D-G-B-E)
- **Auto-detection mode** with visual frequency indicators
- **Real-time audio processing** with optimized performance
- **String-by-string tuning** with color-coded feedback
- **High accuracy** frequency measurement down to cents

![Guitar Tuner](Publishing%20details/Screenshot%202025-08-21%20at%208.50.22%20PM.png)

### 🎼 Metronome
- **Adjustable BPM** from 40 to 240 beats per minute
- **Multiple time signatures** including 6/8, quarter notes, and more
- **Visual beat indicator** with numbered beat markers
- **Tap tempo** functionality for quick BPM setting
- **Subdivision options** for complex rhythm patterns
- **Professional audio engine** for precise timing

![Metronome](Publishing%20details/Screenshot%202025-08-21%20at%208.51.08%20PM.png)

## Technical Highlights

- **SwiftUI** native macOS interface
- **AVFoundation** audio processing
- **Accelerate framework** for high-performance FFT computations
- **Thread-safe audio processing** with optimized performance
- **Real-time frequency analysis** with sub-Hz accuracy
- **Microphone permission handling** with user-friendly alerts

## System Requirements

- macOS 11.0 or later
- Microphone access for tuner functionality
- Audio output for metronome

## Architecture

### Core Components
- **AudioEngine**: Real-time audio processing and FFT analysis
- **MetronomeAudioEngine**: Precision timing and beat generation
- **TunerViewModel**: Guitar tuning logic and frequency processing
- **MetronomeViewModel**: Beat tracking and tempo management
- **PermissionManager**: Microphone access handling

### Audio Processing
- 44.1 kHz sample rate for professional accuracy
- 4096-sample FFT with Hanning window
- Parabolic interpolation for sub-bin frequency accuracy
- Signal strength analysis for noise filtering
- Thread-safe processing with dedicated audio queue

## Installation

1. Clone the repository
2. Open `Guitar Utility.xcodeproj` in Xcode
3. Build and run the application
4. Grant microphone permission when prompted

## Usage

### Tuner Mode
1. Click "Start Tuning" to activate the microphone
2. Play a guitar string
3. Watch the frequency indicator and tune accordingly
4. Green indicators show when strings are in tune

### Metronome Mode
1. Set your desired BPM using the tempo slider
2. Choose time signature and subdivision
3. Click "Start" to begin the metronome
4. Use "Tap Tempo" for quick BPM detection

## Development

Built with:
- **Swift 5.5+**
- **SwiftUI**
- **AVFoundation**
- **Accelerate**
- **Combine**

The application follows MVVM architecture with reactive programming patterns using Combine framework.

## Author

Created by Sachin Kumar

---

*Guitar Utility - Your complete practice companion* 🎸🎼