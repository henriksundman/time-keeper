import SwiftUI

struct SettingsView: View {
    @Bindable var midiManager: MIDIManager
    @Bindable var rhythmEngine: RhythmEngine
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("MIDI Input")
                        .font(.headline)
                    
                    if midiManager.availableSources.isEmpty {
                        ContentUnavailableView {
                            Label("No Devices Found", systemImage: "cable.connector.slash")
                        } description: {
                            Text("Connect a MIDI device to your Mac.")
                        } actions: {
                            Button("Scan Again") {
                                midiManager.scanSources()
                            }
                        }
                    } else {
                        List(midiManager.availableSources) { source in
                            HStack {
                                Text(source.name)
                                Spacer()
                                if midiManager.selectedSource?.id == source.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                midiManager.selectSource(source)
                            }
                        }
                        #if os(macOS)
                        .listStyle(.bordered)
                        #else
                        .listStyle(.insetGrouped)
                        #endif
                        .frame(height: 200)
                    }
                    
                    Divider()
                    
                    Text("Input Settings")
                        .font(.headline)
                    
                    
                    VStack(alignment: .leading) {
                        Text("Chord Debounce: \(Int(rhythmEngine.chordDebounceInterval * 1000)) ms")
                        Slider(value: $rhythmEngine.chordDebounceInterval, in: 0.0...0.100, step: 0.005) {
                            Text("Chord Debounce")
                        } minimumValueLabel: {
                            Text("0ms")
                        } maximumValueLabel: {
                            Text("100ms")
                        }
                        Text("Prevents multiple notes in a chord from registering as multiple beats.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    Text("Note Filter")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        NoteRangeRow(label: "Min Note", value: $midiManager.minNote, range: 0...127, isLearning: learningTarget == .min) {
                            toggleLearning(.min)
                        }
                        NoteRangeRow(label: "Max Note", value: $midiManager.maxNote, range: 0...127, isLearning: learningTarget == .max) {
                            toggleLearning(.max)
                        }
                    }
                    .onChange(of: midiManager.lastReceivedNote) { oldValue, newValue in
                        handleIncomingNote(newValue)
                    }
                    .onChange(of: midiManager.minNote) { oldValue, newValue in
                        // Only clamp if not learning (learning handles its own clamping)
                        // Actually, binding updates minNote directly via slider too.
                        if learningTarget == .none {
                            if newValue > midiManager.maxNote {
                                midiManager.maxNote = newValue
                            }
                        }
                    }
                    .onChange(of: midiManager.maxNote) { oldValue, newValue in
                        if learningTarget == .none {
                            if newValue < midiManager.minNote {
                                midiManager.minNote = newValue
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 400)
            #endif
            .onAppear {
                midiManager.scanSources()
            }
        }
    }
    
    enum LearningTarget {
        case none
        case min
        case max
    }
    
    @State private var learningTarget: LearningTarget = .none
    
    private func toggleLearning(_ target: LearningTarget) {
        if learningTarget == target {
            learningTarget = .none
        } else {
            learningTarget = target
        }
    }
    
    private func handleIncomingNote(_ event: MIDIManager.MIDINoteEvent?) {
        guard learningTarget != .none, let event = event else { return }
        
        let note = Int(event.note)
        
        if learningTarget == .min {
            midiManager.minNote = note.clamped(to: 0...127)
            if midiManager.minNote > midiManager.maxNote {
                 midiManager.maxNote = midiManager.minNote
            }
        } else if learningTarget == .max {
             midiManager.maxNote = note.clamped(to: 0...127)
             if midiManager.maxNote < midiManager.minNote {
                 midiManager.minNote = midiManager.maxNote
             }
        }
        
        learningTarget = .none
    }
}
