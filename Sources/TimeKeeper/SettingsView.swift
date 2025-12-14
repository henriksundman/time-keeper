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
                
                Text("Metronome")
                    .font(.headline)
                
                Picker("Click Mode", selection: $rhythmEngine.clickMode) {
                    Text("Off").tag(RhythmEngine.ClickMode.off)
                    Text("On").tag(RhythmEngine.ClickMode.on)
                    Text("Adaptive").tag(RhythmEngine.ClickMode.adaptive)
                }
                .pickerStyle(.segmented)
                
                if rhythmEngine.clickMode == .adaptive {
                    VStack(alignment: .leading) {
                        Text("Silent Range: +/- \(Int(rhythmEngine.silentRange * 1000)) ms")
                        Slider(value: $rhythmEngine.silentRange, in: 0.0...0.050, step: 0.001) {
                            Text("Silent Range")
                        } minimumValueLabel: {
                            Text("0ms")
                        } maximumValueLabel: {
                            Text("50ms")
                        }
                        Text("Click fades in when deviation exceeds this range.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
