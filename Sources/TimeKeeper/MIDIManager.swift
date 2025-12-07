import Foundation
import CoreMIDI
import os.log

@Observable
class MIDIManager {
    var isConnected = false
    var lastNoteOnTimestamp: Date?
    var onNoteOn: ((Date) -> Void)?
    
    var availableSources: [MIDISourceInfo] = []
    var selectedSource: MIDISourceInfo?
    
    struct MIDISourceInfo: Identifiable, Hashable {
        let id: Int32 // UniqueID
        let name: String
        let endpointRef: MIDIEndpointRef
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private let logger = Logger(subsystem: "com.antigravity.TimeKeeper", category: "MIDIManager")
    
    init() {
        setupMIDI()
    }
    
    private func setupMIDI() {
        var status = MIDIClientCreate("TimeKeeperClient" as CFString, nil, nil, &client)
        if status != noErr {
            logger.error("Error creating MIDI client: \(status)")
            return
        }
        
        status = MIDIInputPortCreateWithBlock(client, "TimeKeeperInput" as CFString, &inputPort) { [weak self] packetList, _ in
            self?.handleMIDIPacketList(packetList)
        }
        
        if status != noErr {
            logger.error("Error creating MIDI input port: \(status)")
            return
        }
        
        scanSources()
    }
    
    func scanSources() {
        var newSources: [MIDISourceInfo] = []
        let sourceCount = MIDIGetNumberOfSources()
        
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            var id: Int32 = 0
            MIDIObjectGetIntegerProperty(source, kMIDIPropertyUniqueID, &id)
            
            var nameRef: Unmanaged<CFString>?
            var name: String = "Unknown Device"
            if MIDIObjectGetStringProperty(source, kMIDIPropertyName, &nameRef) == noErr {
                name = nameRef?.takeRetainedValue() as String? ?? "Unknown"
            }
            
            newSources.append(MIDISourceInfo(id: id, name: name, endpointRef: source))
        }
        
        availableSources = newSources
    }
    
    func selectSource(_ sourceInfo: MIDISourceInfo) {
        // Disconnect old
        if let current = selectedSource {
            MIDIPortDisconnectSource(inputPort, current.endpointRef)
        }
        
        // Connect new
        let status = MIDIPortConnectSource(inputPort, sourceInfo.endpointRef, nil)
        if status == noErr {
            selectedSource = sourceInfo
            isConnected = true
            logger.info("Connected to \(sourceInfo.name)")
        } else {
            logger.error("Failed to connect to \(sourceInfo.name)")
        }
    }
    
    func disconnect() {
        if let current = selectedSource {
            MIDIPortDisconnectSource(inputPort, current.endpointRef)
            selectedSource = nil
            isConnected = false
        }
    }
    
    private func handleMIDIPacketList(_ packetList: UnsafePointer<MIDIPacketList>) {
        let count = packetList.pointee.numPackets
        
        // Safer iteration start
        var ptr = UnsafeRawPointer(packetList).advanced(by: 4).assumingMemoryBound(to: MIDIPacket.self)
        
        for _ in 0..<count {
            let packet = ptr.pointee
            handlePacket(packet)
            ptr = UnsafePointer(MIDIPacketNext(ptr))
        }
    }
    
    private func handlePacket(_ packet: MIDIPacket) {
        // Status byte is in data.0 (tuple)
        // Note On is 0x9n where n is channel 0-15.
        // So 0x90 to 0x9F.
        // Also check velocity (data.2) > 0.
        
        if packet.length >= 3 {
            let status = packet.data.0
            let note = packet.data.1
            let velocity = packet.data.2
            
            let isNoteOn = (status & 0xF0) == 0x90 && velocity > 0
            
            if isNoteOn {
                DispatchQueue.main.async {
                    self.logger.debug("Note On: \(note)")
                    self.onNoteOn?(Date())
                }
            }
        }
    }
}


