import SwiftUI

struct SelectableStringView: View {
    let strings: [GuitarString]
    let selectedString: GuitarString?
    let manualSelection: Bool
    let onStringSelected: (GuitarString) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(strings.sorted(by: { $0.stringNumber > $1.stringNumber })) { string in
                SelectableStringButton(
                    string: string,
                    selectedString: selectedString,
                    manualSelection: manualSelection,
                    onStringSelected: onStringSelected
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SelectableStringButton: View {
    let string: GuitarString
    let selectedString: GuitarString?
    let manualSelection: Bool
    let onStringSelected: (GuitarString) -> Void

    var body: some View {
        Button(action: {
            if manualSelection {
                onStringSelected(string)
            }
        }) {
            VStack(spacing: 4) {
                Circle()
                    .fill(selectedString?.id == string.id ? Color.blue : Color.secondary)
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 0.2), value: selectedString?.id)
                Text(string.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedString?.id == string.id ? Color.blue : Color.secondary)
                Text("\(string.frequency, specifier: "%.1f") Hz")
                    .font(.caption2)
                    .foregroundColor(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedString?.id == string.id ? Color.blue.opacity(0.1) : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .opacity(selectedString?.id == string.id ? 0 : (manualSelection ? 0.5 : 0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedString?.id == string.id ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(selectedString?.id == string.id ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedString?.id)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!manualSelection)
        .help(manualSelection ? "Tap to select \(string.name) string" : "String: \(string.name)")
    }
}

#Preview {
    SelectableStringView(
        strings: GuitarTuning.standard.strings,
        selectedString: GuitarTuning.standard.strings[0],
        manualSelection: true,
        onStringSelected: { _ in }
    )
    .padding()
}
   
