import Foundation

@Observable
class RhythmEngine {
    var currentBPM: Double = 0.0
    var targetBPM: Double = 0.0 // Could be set explicitly or inferred
    var isSteady: Bool = false
    var deviation: Double = 0.0 // Value between -1.0 (early) and 1.0 (late). 0.0 is perfect.
    
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
        targetBPM = currentBPM 
        
        // Calculate deviation of the LATEST tap from the EXPECTED time based on the previous average.
        // Expected time = Previous Tap + AvgInterval
        if timestamps.count >= 3 {
             let lastTap = timestamps.last!
             let prevTap = timestamps[timestamps.count - 2]
             let expectedTime = prevTap.addingTimeInterval(avgInterval)
             
             // Diff
             let diff = lastTap.timeIntervalSince(expectedTime)
             // diff < 0 means early, > 0 means late
             
             // Normalize deviation. Say +/- 0.1s is full range?
             // Or relative to the beat? e.g. 1/4 of a beat.
             // Let's use relative to interval.
             // If diff is +50% of interval, that's huge.
             // Let's map -0.2s ... +0.2s to -1.0 ... 1.0 for visualization.
             
             let sensitivity = 0.2 // 200ms window
             deviation = (diff / sensitivity).clamped(to: -1.0...1.0)
        }
    }
    
    func reset() {
        timestamps.removeAll()
        currentBPM = 0
        deviation = 0
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
