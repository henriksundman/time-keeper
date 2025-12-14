import SwiftUI

struct TempoGaugeView: View {
    let deviation: Double // -1.0 to 1.0
    let isSteady: Bool
    let offset: TimeInterval // in seconds
    
    var body: some View {
        VStack {
            // Gauge logic:
            // Center is 0.
            // Left is early (-1), Right is late (+1).
            
            ZStack {
                // Background Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                
                // Center Marker
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 16)
                
                // Needle
                // Map deviation -1...1 to geometry width
                GeometryReader { geo in
                    let center = geo.size.width / 2
                    let offset = CGFloat(deviation) * (geo.size.width / 2)
                    
                    Circle()
                        .fill(colorForDeviation)
                        .frame(width: 16, height: 16)
                        .position(x: center + offset, y: geo.size.height / 2)
                        .animation(.spring(response: 0.2), value: deviation)
                }
                .frame(height: 16)
            }
            .frame(maxWidth: 300)
            
            HStack {
                Text("Early")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Late")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 300)
            
            Text(offsetFormatted)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(colorForDeviation)
                .padding(.top, 4)
        }
    }
    
    var offsetFormatted: String {
        let ms = Int(offset * 1000)
        if ms > 0 {
            return "+\(ms) ms"
        } else {
            return "\(ms) ms"
        }
    }
    
    var colorForDeviation: Color {
        // Green if close to 0, Yellow/Red if far
        let absDev = abs(deviation)
        if absDev < 0.1 { return .green }
        if absDev < 0.5 { return .yellow }
        return .red
    }
}

#Preview {
    VStack {
        TempoGaugeView(deviation: 0.0, isSteady: true, offset: 0.0)
        TempoGaugeView(deviation: -0.5, isSteady: false, offset: -0.1)
        TempoGaugeView(deviation: 0.8, isSteady: false, offset: 0.16)
    }
    .padding()
}
