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
            
            // Interaction Gauge
            TempoGaugeView(deviation: rhythmEngine.deviation, isSteady: rhythmEngine.isSteady)
                .padding(.horizontal)
            
            Spacer()
            
            Button("Reset") {
                rhythmEngine.reset()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView(midiManager: midiManager)
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
