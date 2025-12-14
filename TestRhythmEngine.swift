
import Foundation

// Mocking the class structure for standalone execution
class RhythmEngine {
    var currentBPM: Double = 0.0
    var targetBPM: Double = 0.0
    var isFixedTempo: Bool = false
    var fixedBPM: Double = 120.0
    var isSteady: Bool = false
    var deviation: Double = 0.0
    
    private var timestamps: [Date] = []
    private let historySize = 5
    
    func registerTap(at timestamp: Date) {
        timestamps.append(timestamp)
        if timestamps.count > historySize {
            timestamps.removeFirst()
        }
        calculateTempo()
    }
    
    private func calculateTempo() {
        guard timestamps.count >= 2 else { return }
        
        var intervals: [TimeInterval] = []
        for i in 1..<timestamps.count {
            let interval = timestamps[i].timeIntervalSince(timestamps[i-1])
            intervals.append(interval)
        }
        
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let instantaneousBPM = 60.0 / avgInterval
        currentBPM = instantaneousBPM
        
        if isFixedTempo {
            targetBPM = fixedBPM
        } else {
            targetBPM = currentBPM
        }
        
        if timestamps.count >= 2 {
             let targetInterval = 60.0 / targetBPM
             
             let lastTap = timestamps.last!
             let prevTap = timestamps[timestamps.count - 2]
             let expectedTime = prevTap.addingTimeInterval(targetInterval)
             
             let diff = lastTap.timeIntervalSince(expectedTime)
             
             let sensitivity = 0.2
             deviation = min(max(diff / sensitivity, -1.0), 1.0)
        }
    }
    
    func reset() {
        timestamps.removeAll()
        currentBPM = 0
        deviation = 0
    }
}

// Test Runner
func runTests() {
    let engine = RhythmEngine()
    
    print("Test 1: Adaptive Mode")
    engine.isFixedTempo = false
    let start = Date()
    // Tap at 120 BPM (0.5s)
    engine.registerTap(at: start)
    engine.registerTap(at: start.addingTimeInterval(0.5))
    engine.registerTap(at: start.addingTimeInterval(1.0))
    
    print("Adaptive BPM: \(engine.currentBPM) (Expected: 120)")
    print("Adaptive Target: \(engine.targetBPM) (Expected: 120)")
    print("Adaptive Deviation: \(engine.deviation) (Expected: 0.0)")
    
    print("\nTest 2: Fixed Mode (Same Tempo)")
    engine.reset()
    engine.isFixedTempo = true
    engine.fixedBPM = 120.0
    
    engine.registerTap(at: start)
    engine.registerTap(at: start.addingTimeInterval(0.5))
    engine.registerTap(at: start.addingTimeInterval(1.0))
    
    print("Fixed(120) BPM: \(engine.currentBPM) (Expected: 120)")
    print("Fixed(120) Target: \(engine.targetBPM) (Expected: 120)")
    print("Fixed(120) Deviation: \(engine.deviation) (Expected: 0.0)")
    
    print("\nTest 3: Fixed Mode (Significantly Faster)")
    engine.reset()
    engine.isFixedTempo = true
    engine.fixedBPM = 60.0 // Target is 60 (1.0s interval)
    
    // Tap at 120 BPM (0.5s interval) - playing DOUBLE speed
    engine.registerTap(at: start)
    engine.registerTap(at: start.addingTimeInterval(0.5))
    engine.registerTap(at: start.addingTimeInterval(1.0))
    
    print("Fixed(60) vs Input(120) BPM: \(engine.currentBPM) (Expected: 120)")
    print("Fixed(60) vs Input(120) Target: \(engine.targetBPM) (Expected: 60)")
    // Difference is 0.5s (Actual) - 1.0s (Expected) = -0.5s
    // Sensitivity 0.2s. Deviation = -0.5/0.2 = -2.5 -> Clamped to -1.0
    print("Fixed(60) vs Input(120) Deviation: \(engine.deviation) (Expected: -1.0)")
}

runTests()
