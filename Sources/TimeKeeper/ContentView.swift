import SwiftUI

struct ContentView: View {
    @State private var midiManager = MIDIManager()
    @State private var rhythmEngine = RhythmEngine()
    
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack {
                HStack {
                    Text("TimeKeeper")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Image(systemName: midiManager.isConnected ? "midi.connector.fill" : "midi.connector")
                        .foregroundStyle(midiManager.isConnected ? .green : .red)
                    Text(midiManager.isConnected ? "Connected: \(midiManager.selectedSource?.name ?? "Unknown")" : "No Device Selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // BPM Display
            VStack {
                Text(String(format: "%.1f", rhythmEngine.currentBPM))
                    .font(.system(size: 72, weight: .heavy, design: .monospaced))
                    .contentTransition(.numericText(value: rhythmEngine.currentBPM))
                    .animation(.default, value: rhythmEngine.currentBPM)
                
                Text("BPM")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            // Visualizer
            BouncingBallView(bpm: rhythmEngine.isFixedTempo ? rhythmEngine.fixedBPM : rhythmEngine.currentBPM, referenceTime: rhythmEngine.referenceBeatTime, taps: rhythmEngine.timestamps)
                .frame(height: 120)
                .padding(.horizontal)
            
            // Interaction Gauge
            TempoGaugeView(deviation: rhythmEngine.deviation, isSteady: rhythmEngine.isSteady, offset: rhythmEngine.lastOffset)
                .padding(.horizontal)
            
            
            // Mode Control
            VStack {
                Picker("Mode", selection: $rhythmEngine.isFixedTempo) {
                    Text("Adaptive").tag(false)
                    Text("Fixed").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                
                if rhythmEngine.isFixedTempo {
                    HStack {
                        Text("Target: \(Int(rhythmEngine.fixedBPM))")
                            .monospacedDigit()
                        Slider(value: $rhythmEngine.fixedBPM, in: 20...400, step: 1)
                    }
                    .frame(maxWidth: 300)
                    .padding(.top, 10)
                }
                
                // Only show Metronome controls in Fixed Mode
                if rhythmEngine.isFixedTempo {
                    Divider()
                        .frame(width: 200)
                        .padding(.vertical)
                    
                    VStack(spacing: 12) {
                        Picker("Metronome", selection: $rhythmEngine.clickMode) {
                            Text("Off").tag(RhythmEngine.ClickMode.off)
                            Text("On").tag(RhythmEngine.ClickMode.on)
                            Text("Adaptive").tag(RhythmEngine.ClickMode.adaptive)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                        
                        if rhythmEngine.clickMode == .adaptive {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("Silent Range")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("+/- \(Int(rhythmEngine.silentRange * 1000)) ms")
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                                
                                Slider(value: $rhythmEngine.silentRange, in: 0.0...0.050, step: 0.001)
                            }
                            .frame(maxWidth: 250)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                rhythmEngine.isActive.toggle()
            }) {
                Image(systemName: rhythmEngine.isActive ? "stop.fill" : "play.fill")
                    .font(.largeTitle)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(rhythmEngine.isActive ? .red : .green)
            .padding(.bottom)
        }
        .padding()
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 450)
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView(midiManager: midiManager, rhythmEngine: rhythmEngine)
        }
        .onAppear {
            // Bind MIDI to Engine
            midiManager.onNoteOn = { timestamp in
                rhythmEngine.registerTap(at: timestamp)
            }
            
            // Initial scan
            midiManager.scanSources()
            
            // Auto-select first if available and none selected?
            if midiManager.selectedSource == nil, let first = midiManager.availableSources.first {
                midiManager.selectSource(first)
            }
        }
    }
}

#Preview {
    ContentView()
}
