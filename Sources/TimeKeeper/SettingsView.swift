import SwiftUI

struct SettingsView: View {
    @Bindable var midiManager: MIDIManager
    @Bindable var rhythmEngine: RhythmEngine
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
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
                
                Spacer()
            }
            .padding()
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
            .frame(width: 400, height: 400)
            #endif
            .onAppear {
                midiManager.scanSources()
            }
        }
    }
}
