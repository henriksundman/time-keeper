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
                // Define the visual ground line
                let visualGroundY = height - 30
                
                ctx.stroke(Path { path in
                    path.move(to: CGPoint(x: 0, y: visualGroundY))
                    path.addLine(to: CGPoint(x: width, y: visualGroundY))
                }, with: .color(.gray.opacity(0.5)), lineWidth: 1)
                
                // Draw Trajectory
                // We want to map X to Time.
                
                let ballX = size.width * 0.5
                
                // Ball Calculation Base Height
                // calculateY returns the center Y of the ball.
                // We want the bottom of the ball to touch visualGroundY when yNorm is 0.
                // Bottom = Center + Radius
                // visualGroundY = Center + ballSize/2
                // Center = visualGroundY - ballSize/2
                // So pass (visualGroundY - ballSize/2) as the 'height' parameter to calculateY.
                let ballCenterBaseY = visualGroundY - ballSize / 2
                
                if let ref = referenceTime, bpm > 0 {
                    let secondsPerBeat = 60.0 / bpm
                    
                    var path = Path()
                    let step = 5.0 // pixels
                    
                    // Start from a bit off-screen left
                    for x in stride(from: -50, to: width, by: step) {
                        let xOffset = x - ballX
                        let timeOffset = xOffset / speed
                        let t = now.addingTimeInterval(TimeInterval(timeOffset))
                        
                        let y = calculateY(at: t, reference: ref, period: secondsPerBeat, height: ballCenterBaseY)
                        
                        // calculateY returns center. Path should track center or bottom?
                        // Visually, the curve tracks the center of the ball.
                        
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
                    
                    // 1. Reference Dots (The Grid)
                    // We need to find "grid beats" that are visible on screen.
                    // Visible time range relative to now:
                    // Left edge x=0 -> t_min = now + (0 - ballX)/speed
                    // Right edge x=width -> t_max = now + (width - ballX)/speed
                    
                    let t_min_offset = (0 - ballX) / speed
                    let t_max_offset = (width - ballX) / speed
                    
                    let refOffset = now.timeIntervalSince(ref)
                    // We want times T_grid such that (T_grid - ref) is multiple of secondsPerBeat.
                    // T_grid = ref + k * period
                    // Relative to now: offset_grid = T_grid - now = ref - now + k*period
                    // offset_grid = -refOffset + k*period
                    
                    // We need t_min_offset <= -refOffset + k*period <= t_max_offset
                    // t_min_offset + refOffset <= k*period <= t_max_offset + refOffset
                    // (t_min_offset + refOffset)/period <= k <= (t_max_offset + refOffset)/period
                    
                    let k_min = ceil((t_min_offset + refOffset) / secondsPerBeat)
                    let k_max = floor((t_max_offset + refOffset) / secondsPerBeat)
                    
                    if k_min <= k_max {
                        for k in stride(from: k_min, through: k_max, by: 1.0) {
                            let kDouble = Double(k)
                            let gridTimeOffset = -refOffset + kDouble * secondsPerBeat
                            let x = (gridTimeOffset * speed) + Double(ballX)
                             
                            // Draw Reference Dot (Below ground)
                            let refRect = CGRect(x: x - 3, y: visualGroundY + 12, width: 6, height: 6)
                            ctx.fill(Circle().path(in: refRect), with: .color(.gray)) // Increased opacity for visibility
                        }
                    }
                    
                    // 2. Played Taps (On ground)
                    for tap in taps {
                        let diff = tap.timeIntervalSince(now)
                        let x = (diff * speed) + Double(ballX)
                        
                        // Check visibility
                        if x >= -20 && x <= size.width + 20 {
                            let tapRect = CGRect(x: x - 4, y: visualGroundY - 4, width: 8, height: 8)
                            ctx.fill(Circle().path(in: tapRect), with: .color(.green))
                        }
                    }
                    
                    // Draw Ball at ballX, y(now)
                    let currentY = calculateY(at: now, reference: ref, period: secondsPerBeat, height: ballCenterBaseY)
                    let ballRect = CGRect(x: ballX - ballSize/2, y: currentY - ballSize/2, width: ballSize, height: ballSize)
                    ctx.fill(Circle().path(in: ballRect), with: .color(.primary))
                    
                } else {
                    // Resting state
                    let visualGroundY = height - 30
                    let ballRect = CGRect(x: ballX - ballSize/2, y: visualGroundY - ballSize, width: ballSize, height: ballSize)
                    ctx.fill(Circle().path(in: ballRect), with: .color(.secondary))
                    
                    // Draw ground too for consistency
                     ctx.stroke(Path { path in
                        path.move(to: CGPoint(x: 0, y: visualGroundY))
                        path.addLine(to: CGPoint(x: width, y: visualGroundY))
                    }, with: .color(.gray.opacity(0.5)), lineWidth: 1)
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
