import SwiftUI

/// Animated pulse-ring indicator with gradient rings that ripple outward.
struct PulseRingView: View {
    private let size: CGFloat = 18
    private let ringCount = 3

    private let gradient = AngularGradient(
        colors: [
            Color(hex: 0xD97757),
            Color(hex: 0xE8956E),
            Color(hex: 0xC25D3F),
            Color(hex: 0xD97757),
        ],
        center: .center
    )

    @State private var animated = false

    var body: some View {
        ZStack {
            // Center dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xE8956E), Color(hex: 0xD97757)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 6, height: 6)
                .scaleEffect(animated ? 1.0 : 0.7)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: animated
                )

            // Ripple rings
            ForEach(0..<ringCount, id: \.self) { index in
                Circle()
                    .strokeBorder(gradient, lineWidth: 1.5)
                    .frame(width: size, height: size)
                    .scaleEffect(animated ? 1.4 : 0.4)
                    .opacity(animated ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.6),
                        value: animated
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear { animated = true }
        .onDisappear { animated = false }
    }
}

private extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
