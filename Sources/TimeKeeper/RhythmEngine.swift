import Foundation

@Observable
class RhythmEngine {
    enum ClickMode {
        case off
        case on
        case adaptive
    }
    
    var currentBPM: Double = 0.0
    var targetBPM: Double = 0.0 // Could be set explicitly or inferred
    var isFixedTempo: Bool = true {
        didSet { updateMetronome() }
    }
    var fixedBPM: Double = 120.0 {
        didSet { updateMetronome() }
    }
    
    var clickMode: ClickMode = .on {
        didSet { updateMetronome() }
    }
    var silentRange: TimeInterval = 0.010 // +/- 10ms
    
    private let metronome = Metronome()
    
    var isSteady: Bool = false
    var deviation: Double = 0.0 // Value between -1.0 (early) and 1.0 (late). 0.0 is perfect.
    var lastOffset: TimeInterval = 0.0 // Raw difference in seconds (negative = early, positive = late)
    var referenceBeatTime: Date? // Anchor for visualizer (Phase)
    
    var isActive: Bool = false {
        didSet {
            if !isActive {
                reset()
            }
            updateMetronome()
        }
    }
    
    var timestamps: [Date] = [] // Public for visualization
    private let maxHistory = 50 // Keep more for visualizer
    private let calculationWindow = 5 // Use few for responsive tempo calc
    
    func registerTap(at timestamp: Date) {
        timestamps.append(timestamp)
        if timestamps.count > maxHistory {
            timestamps.removeFirst()
        }
        
        calculateTempo()
    }
    
    private func calculateTempo() {
        guard timestamps.count >= 2 else { return }
        
        // Calculate intervals
        var intervals: [TimeInterval] = []
        // Use only the last N taps for calculation
        let recentTaps = timestamps.suffix(calculationWindow)
        guard recentTaps.count >= 2 else { return }
        
        let tapArray = Array(recentTaps)
        for i in 1..<tapArray.count {
            let interval = tapArray[i].timeIntervalSince(tapArray[i-1])
            intervals.append(interval)
        }
        
        // Average interval
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        
        // BPM = 60 / interval
        let instantaneousBPM = 60.0 / avgInterval
        currentBPM = instantaneousBPM
        
        // Heuristic for "established" tempo:
        // If we have enough consistent data, we lock onto a target.
        // For now, let's just make the target the average.
        if isFixedTempo {
            targetBPM = fixedBPM
        } else {
            targetBPM = currentBPM
        }
        
        // Calculate deviation of the LATEST tap from the EXPECTED time.
        // Expected time = Previous Tap + TargetInterval
        if recentTaps.count >= 2 { // We can check deviation as soon as we have an interval if we have a target
             // Ideally we want to compare against the *target* interval, not just the average.
             let targetInterval = 60.0 / targetBPM
             
             let lastTap = timestamps.last!
             let prevTap = timestamps[timestamps.count - 2]
             let expectedTime = prevTap.addingTimeInterval(targetInterval)
             
             // Diff
             let diff = lastTap.timeIntervalSince(expectedTime)
             lastOffset = diff
             // diff < 0 means early, > 0 means late
             
             let sensitivity = 0.2 // 200ms window
             deviation = (diff / sensitivity).clamped(to: -1.0...1.0)
             
             // In Adaptive mode, we anchor the grid to the user's perception (or smoothed?)
             // Using expectedTime keeps it smoother than snapping to every tap if the taps are jittery.
             // But snapping to actual tap feels more "responsive" to tempo changes.
             // Let's stick to the latest tap as the "truth" for now.
             if !isFixedTempo {
                 referenceBeatTime = lastTap
             }
        } else if timestamps.count == 1 {
             if !isFixedTempo {
                 referenceBeatTime = timestamps.first
             }
        }
        
        updateMetronome()
    }
    
    private func updateMetronome() {
        // Update BPM
        if isFixedTempo {
             metronome.bpm = fixedBPM
             // We wait for metronome.onStart to set referenceBeatTime for perfect sync!
             // if referenceBeatTime == nil || !metronome.isPlaying {
             //      referenceBeatTime = Date()
             // }
        } else {
             // If adaptive, maybe track current BPM? 
             // For now, if not fixed, we don't really have a stable target to click to,
             // unless we use targetBPM inferred from tapping.
             if targetBPM > 0 {
                 metronome.bpm = targetBPM
             }
        }
        
        // Mode Logic
        // "In adaptive tempo mode, disable the click for now"
        if !isActive || !isFixedTempo {
            metronome.stop()
            return
        }
        
        switch clickMode {
        case .off:
            metronome.stop()
        case .on:
            metronome.volume = 1.0
            metronome.start()
        case .adaptive:
            // Calculate volume based on accuracy
            // If |offset| < silentRange, volume = 0
            // Else, fade in. Let's say max volume at 100ms error?
            let absOffset = abs(lastOffset)
            if absOffset <= silentRange {
                metronome.volume = 0.0
            } else {
                // Fade range
                let maxDev = 0.100 // 100ms
                let fade = (absOffset - silentRange) / (maxDev - silentRange)
                metronome.volume = Float(fade.clamped(to: 0.0...1.0))
            }
            metronome.start()
        }
    }
    
    init() {
        // Ensure initial state is valid
        // Auto-start disabled. User must press Play.
        metronome.onStart = { [weak self] startTime in
            guard let self = self, self.isFixedTempo else { return }
            self.referenceBeatTime = startTime
        }
    }
    
    func reset() {
        timestamps.removeAll()
        currentBPM = 0
        deviation = 0
        lastOffset = 0
        referenceBeatTime = nil
        metronome.stop()
    }
    
    // Helper to start fixed tempo anchor if needed
    // Called when toggling to Fixed or changing Fixed BPM
    // For now, let's just rely on the metronome start time? 
    // Or we can just set referenceBeatTime = Date() when we start fixed mode.
    // Ideally this is handled in updateMetronome or property observer.
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
