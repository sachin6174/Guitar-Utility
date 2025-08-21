import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .tuner
    @StateObject private var tunerViewModel = TunerViewModel()
    @StateObject private var metronomeViewModel = MetronomeViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .tuner:
                    TunerView(viewModel: tunerViewModel)
                case .metronome:
                    MetronomeView(viewModel: metronomeViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            TabBarView(selectedTab: $selectedTab)
        }
        .frame(width: 500, height: 800) // Reduced from 850 to 800
        .background(.regularMaterial)
    }
}

enum AppTab: String, CaseIterable {
    case tuner = "Tuner"
    case metronome = "Metronome"
    
    var iconName: String {
        switch self {
        case .tuner: return "tuningfork"
        case .metronome: return "metronome"
        }
    }
}

struct TabBarView: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: tab.iconName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        }
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(.separator.opacity(0.5))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

#Preview {
    ContentView()
}
