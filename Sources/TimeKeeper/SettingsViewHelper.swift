import SwiftUI

struct NoteRangeRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let isLearning: Bool
    let onLearnToggle: () -> Void
    
    // Notes array for conversion
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    private var noteName: String {
        midiToNoteName(value)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                
                Button(action: onLearnToggle) {
                    Group {
                        if isLearning {
                            Text("Listening...")
                                .foregroundStyle(.red)
                                .bold()
                        } else {
                            Text(noteName)
                                .monospaced()
                                .bold()
                        }
                    }
                    .frame(width: 100, alignment: .trailing)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(isLearning ? Color.red.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                    // If not learning, look like a standard value?
                    // User requested "whatever midi note is received is the note set".
                    // A button style indicating interactivity is good.
                }
                .buttonStyle(.plain)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isLearning ? Color.red : Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            
            Slider(value: Binding(get: {
                Double(value)
            }, set: {
                value = Int($0)
            }), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        }
    }
    
    private func midiToNoteName(_ midi: Int) -> String {
        let octave = (midi / 12) - 1
        let noteIndex = midi % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}
