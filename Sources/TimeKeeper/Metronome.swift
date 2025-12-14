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
        player.play()
        
        // Schedule first click immediately (or slightly in future to be safe)
        // Using sample time for precision
        
        // Ideally we want to sync this with RhythmEngine's concept of time.
        // For now, let's just run a free loop.
        
        scheduleClicks()
    }
    
    func stop() {
        isPlaying = false
        player.stop()
        player.reset() // Clears scheduled events
        nextClickTime = nil
    }
    
    private func scheduleClicks() {
        guard isPlaying, let buffer = buffer, let format = processingFormat else { 
            print("Metronome: Early return - isPlaying: \(isPlaying), buffer: \(buffer != nil), format: \(processingFormat != nil)")
            return 
        }
        
        // Calculate sample distance for BPM
        // 60 seconds / BPM = seconds per beat
        // seconds * sampleRate = frames
        let secondsPerBeat = 60.0 / bpm
        let framesPerBeat = AVAudioFramePosition(secondsPerBeat * format.sampleRate)
        
        // If we don't have a next time, start "now"
        var nowMatches = false
        let now: AVAudioTime
        if let lastRenderTime = player.lastRenderTime {
            now = lastRenderTime
        } else {
            // Player hasn't started rendering yet?
            // Fallback to sample time 0 is risky if engine has been running.
            // But if engine is running, lastRenderTime should be valid unless player isn't playing.
            print("Metronome: player.lastRenderTime is nil")
            now = AVAudioTime(sampleTime: 0, atRate: format.sampleRate)
        }
        
        var startTime = nextClickTime ?? now
        
        // Clean up backward times just in case
        if startTime.sampleTime < now.sampleTime {
            print("Metronome: startTime fell behind. Resetting to now.")
            startTime = now
        }
        
        // For first start, maybe push it slightly ahead to avoid "late" render
        if nextClickTime == nil {
             // 0.1s ahead
             startTime = AVAudioTime(sampleTime: now.sampleTime + AVAudioFramePosition(0.1 * format.sampleRate), atRate: format.sampleRate)
        }
        
        // Schedule a few beats ahead
        for i in 0..<4 {
             player.scheduleBuffer(buffer, at: startTime, options: .interrupts) {
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
            self?.scheduleClicks()
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
