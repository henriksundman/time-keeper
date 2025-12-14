import Foundation
import AVFoundation

class Metronome {
    private var engine: AVAudioEngine
    private var player: AVAudioPlayerNode
    private var buffer: AVAudioPCMBuffer?
    private var processingFormat: AVAudioFormat?
    
    private var queue = DispatchQueue(label: "com.antigravity.Metronome", qos: .userInteractive)
    
    var bpm: Double = 120.0 {
        didSet {
            // Update scheduling if playing? 
            // For simplicity, changes take effect on next schedule cycle or restart.
        }
    }
    
    var volume: Float = 1.0 {
        didSet {
            player.volume = volume
        }
    }
    
    private(set) var isPlaying = false
    private var nextClickTime: AVAudioTime?
    private var generation = 0
    
    init() {
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        engine.attach(player)
        
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        processingFormat = format
        
        // Connect player to mixer
        engine.connect(player, to: mixer, format: format)
        
        // Prepare buffer (Click Sound)
        // Synthesize a simple beep/tick
        buffer = generateClickBuffer(format: format)
        
        // Pre-start engine
        do {
            try engine.start()
            print("Metronome: Engine started. Format: \(format). Mixer running: \(engine.isRunning)")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
        
        if buffer == nil {
            print("Metronome: Failed to generate click buffer")
        } else {
            print("Metronome: Info - Buffer frame length: \(buffer?.frameLength ?? 0)")
        }
    }
    
    func start() {
        guard !isPlaying else { return }
        // Ensure engine is running
        if !engine.isRunning {
             try? engine.start()
        }
        
        isPlaying = true
        generation += 1
        player.play()
        
        // Schedule first click immediately (or slightly in future to be safe)
        // Using sample time for precision
        
        // Ideally we want to sync this with RhythmEngine's concept of time.
        // For now, let's just run a free loop.
        
        scheduleClicks(forGenerator: generation)
    }
    
    func stop() {
        print("Metronome: Stop called")
        isPlaying = false
        generation += 1 // Invalidate current loop
        player.stop()
        player.reset() // Clears scheduled events
        nextClickTime = nil
    }
    
    var onStart: ((Date) -> Void)?
    
    private func scheduleClicks(forGenerator gen: Int) {
        guard isPlaying, gen == generation, let buffer = buffer, let format = processingFormat else { 
            if gen != generation {
                print("Metronome: Stale generation \(gen) vs \(generation). Stopping loop.")
            } else {
                print("Metronome: Early return - isPlaying: \(isPlaying), buffer: \(buffer != nil), format: \(processingFormat != nil)")
            }
            return 
        }
        
        // Calculate sample distance for BPM
        // 60 seconds / BPM = seconds per beat
        // seconds * sampleRate = frames
        let secondsPerBeat = 60.0 / bpm
        let framesPerBeat = AVAudioFramePosition(secondsPerBeat * format.sampleRate)
        
        // If we don't have a next time, start "now"
        var nowMatches = false
        var startTime: AVAudioTime
        
        if let next = nextClickTime {
            startTime = next
        } else {
            // First click!
            // Use host time for immediate start
            let hostTime = mach_absolute_time()
            let nowAudio = AVAudioTime(hostTime: hostTime)
            
            // Allow a tiny safety margin (e.g. 50ms) for the scheduler to process
            // But getting the actual date is tricky if we add offset.
            // Let's rely on hostTime which is "now".
            // Adding a small offset in samples to be safe.
            // 0.05s * sampleRate
            let offsetSamples = AVAudioFramePosition(0.05 * format.sampleRate)
            startTime = AVAudioTime(hostTime: hostTime, sampleTime: nowAudio.sampleTime + offsetSamples, atRate: format.sampleRate)
            
            // Notify listener (RhythmEngine) of the EXACT start time (Date)
            // hostTime -> Date
            // Date() is roughly now.
            // Ideally we convert mach absolute time to Date.
            // Or we just capture Date() + 0.05s
            DispatchQueue.main.async {
                self.onStart?(Date().addingTimeInterval(0.05))
            }
        }
        
        // Clean up backward times just in case (mostly for nextClickTime iteration logic if drift happens)
        // But for hostTime-based start, we are by definition "future".
        
        // Schedule a few beats ahead
        for i in 0..<4 {
             // IMPORT: Do NOT use .interrupts here, or it wipes the previous iterations!
             var options: AVAudioPlayerNodeBufferOptions = []
             
             player.scheduleBuffer(buffer, at: startTime, options: options) {
                 // Completion handler (optional)
             }
             
             // Advance time
             let nextSampleTime = startTime.sampleTime + framesPerBeat
             startTime = AVAudioTime(sampleTime: nextSampleTime, atRate: format.sampleRate)
        }
        
        nextClickTime = startTime
        
        // Re-schedule in a bit
        // Roughly wait half the duration of the scheduled clicks
        let waitSeconds = (secondsPerBeat * 2.0)
        queue.asyncAfter(deadline: .now() + waitSeconds) { [weak self] in
            self?.scheduleClicks(forGenerator: gen)
        }
    }
    
    private func generateClickBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // High pitched short beep
        let frequency = 1000.0 // Hz
        let duration = 0.05 // seconds
        
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        
        buffer.frameLength = frameCount
        
        let channels = Int(format.channelCount)
        for channel in 0..<channels {
            guard let floatData = buffer.floatChannelData?[channel] else { continue }
            for i in 0..<Int(frameCount) {
                // Sine wave
                let theta = 2.0 * .pi * frequency * Double(i) / format.sampleRate
                
                // Env: fast attack, exp decay
                let t = Double(i) / Double(frameCount)
                let env = 1.0 - t
                
                floatData[i] = Float(sin(theta) * env)
            }
        }
        
        return buffer
    }
}
