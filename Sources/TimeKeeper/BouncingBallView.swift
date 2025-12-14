import SwiftUI

struct BouncingBallView: View {
    var bpm: Double
    var referenceTime: Date?
    var taps: [Date] // History of taps
    
    // Config
    private let ballSize: CGFloat = 20
    private let speed: Double = 200.0 // Points per second for scrolling
    
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let now = context.date
                let width = size.width
                let height = size.height
                
                // Draw Ground
                let groundY = height - ballSize / 2
                ctx.stroke(Path { path in
                    path.move(to: CGPoint(x: 0, y: groundY))
                    path.addLine(to: CGPoint(x: width, y: groundY))
                }, with: .color(.gray.opacity(0.5)), lineWidth: 1)
                
                // Draw Trajectory
                // We want to map X to Time.
                // Ball X is fixed at e.g. 20% width? Or center?
                // User said "move from right to left".
                // This means future is to the Right. Past is to the Left.
                // Curve moves Left.
                
                let ballX = size.width * 0.5
                
                // Calculate trajectory path
                // t = now + (x - ballX) / speed
                // x range: 0 to width
                
                if let ref = referenceTime, bpm > 0 {
                    let secondsPerBeat = 60.0 / bpm
                    
                    var path = Path()
                    let step = 5.0 // pixels
                    
                    // Start from a bit off-screen left
                    for x in stride(from: -50, to: width, by: step) {
                        let xOffset = x - ballX
                        let timeOffset = xOffset / speed
                        let t = now.addingTimeInterval(TimeInterval(timeOffset))
                        
                        let y = calculateY(at: t, reference: ref, period: secondsPerBeat, height: height - ballSize)
                        
                        if x == -50 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    ctx.stroke(path, with: .color(.blue.opacity(0.8)), lineWidth: 3)
                    
                    // Draw Taps
                    // Draw dots for each tap at appropriate X
                    // x = (t - now) * speed + ballX
                    // t = tap.timestamp
                    
                    for tap in taps {
                        let diff = tap.timeIntervalSince(now)
                        let x = (diff * speed) + Double(ballX)
                        
                        // Check visibility
                        if x >= -20 && x <= size.width + 20 {
                            let tapRect = CGRect(x: x - 4, y: groundY - 4, width: 8, height: 8)
                            ctx.fill(Circle().path(in: tapRect), with: .color(.green))
                        }
                    }
                    
                    // Draw Ball at ballX, y(now)
                    let currentY = calculateY(at: now, reference: ref, period: secondsPerBeat, height: height - ballSize)
                    let ballRect = CGRect(x: ballX - ballSize/2, y: currentY - ballSize/2, width: ballSize, height: ballSize)
                    ctx.fill(Circle().path(in: ballRect), with: .color(.primary))
                    
                } else {
                    // Resting state
                    let ballRect = CGRect(x: ballX - ballSize/2, y: groundY - ballSize/2, width: ballSize, height: ballSize)
                    ctx.fill(Circle().path(in: ballRect), with: .color(.secondary))
                }
            }
        }
        .frame(height: 150)
        .clipped()
    }
    
    func calculateY(at time: Date, reference: Date, period: Double, height: CGFloat) -> CGFloat {
        // Phase calculation
        let diff = time.timeIntervalSince(reference)
        
        // We want diff=0 to be a bounce (y=ground).
        // Since y=0 is TOP in SwiftUI, ground is max Y (height).
        // Parabola: 4 * t * (1-t) is 0 at 0, 1 at 0.5, 0 at 1.
        // We need 0 at multiples of period.
        
        // Normalize diff to 0...1 within period
        // diff can be negative.
        let phase = (diff.truncatingRemainder(dividingBy: period)) / period
        
        // Make sure phase is positive 0...1
        let normalizedPhase = phase >= 0 ? phase : phase + 1.0
        
        // 0.0 -> Ground
        // 0.5 -> Peak
        // 1.0 -> Ground
        
        let yNorm = 4.0 * normalizedPhase * (1.0 - normalizedPhase)
        
        // Map to screen
        // Ground is 'height'. Peak is 0 (or some top margin).
        // Let's say peak height is 80% of view height.
        
        let peakAmplitude = height * 0.8
        let yPos = height - (CGFloat(yNorm) * peakAmplitude)
        
        return yPos
    }
}

#Preview {
    BouncingBallView(bpm: 120, referenceTime: Date(), taps: [])
}
