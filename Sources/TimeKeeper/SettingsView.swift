import SwiftUI

struct SettingsView: View {
    @Bindable var midiManager: MIDIManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .bold()
            
            Divider()
            
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
                .listStyle(.bordered)
                .frame(height: 200)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
        .onAppear {
            midiManager.scanSources()
        }
    }
}
