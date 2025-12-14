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
    var isFixedTempo: Bool = false {
        didSet { updateMetronome() }
    }
    var fixedBPM: Double = 120.0 {
        didSet { updateMetronome() }
    }
    
    var clickMode: ClickMode = .off {
        didSet { updateMetronome() }
    }
    var silentRange: TimeInterval = 0.010 // +/- 10ms
    
    private let metronome = Metronome()
    
    var isSteady: Bool = false
    var deviation: Double = 0.0 // Value between -1.0 (early) and 1.0 (late). 0.0 is perfect.
    var lastOffset: TimeInterval = 0.0 // Raw difference in seconds (negative = early, positive = late)
    
    private var timestamps: [Date] = []
    private let historySize = 5 // Number of beats to average
    
    func registerTap(at timestamp: Date) {
        timestamps.append(timestamp)
        if timestamps.count > historySize {
            timestamps.removeFirst()
        }
        
        calculateTempo()
    }
    
    private func calculateTempo() {
        guard timestamps.count >= 2 else { return }
        
        // Calculate intervals
        var intervals: [TimeInterval] = []
        for i in 1..<timestamps.count {
            let interval = timestamps[i].timeIntervalSince(timestamps[i-1])
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
        if timestamps.count >= 2 { // We can check deviation as soon as we have an interval if we have a target
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
        }
        updateMetronome()
    }
    
    private func updateMetronome() {
        // Update BPM
        if isFixedTempo {
             metronome.bpm = fixedBPM
        } else {
             // If adaptive, maybe track current BPM? 
             // For now, if not fixed, we don't really have a stable target to click to,
             // unless we use targetBPM inferred from tapping.
             if targetBPM > 0 {
                 metronome.bpm = targetBPM
             }
        }
        
        // Mode Logic
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
    
    func reset() {
        timestamps.removeAll()
        currentBPM = 0
        deviation = 0
        lastOffset = 0
        metronome.stop()
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
