import SwiftUI

/// Warm paper with a soft glow in the stage's color, a little grain, and the
/// racing stripes along the top edge.
struct RetroBackground: View {
    var accent: Color

    var body: some View {
        ZStack(alignment: .top) {
            Theme.paper
            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 720
            )
            PaperGrain()
            RetroStripes(thickness: 5, spacing: 3)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A fixed sprinkle of specks, like old printed paper. It never animates.
struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            var generator = SeededGenerator(seed: 0x5EED_F0C5)
            let count = Int(size.width * size.height / 420)
            let speck = GraphicsContext.Shading.color(Theme.ink.opacity(0.05))
            for _ in 0..<count {
                let x = CGFloat.random(in: 0..<size.width, using: &generator)
                let y = CGFloat.random(in: 0..<size.height, using: &generator)
                let side = CGFloat.random(in: 0.6..<1.6, using: &generator)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)), with: speck)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Slowly turning sunburst rays behind a finished focus.
struct Sunburst: View {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let degrees = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 360) * 4
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
                let radius = hypot(size.width, size.height)
                let rays = 24
                for index in stride(from: 0, to: rays, by: 2) {
                    let start = Angle.degrees(Double(index) * 360 / Double(rays) + degrees)
                    let end = Angle.degrees(Double(index + 1) * 360 / Double(rays) + degrees)
                    var path = Path()
                    path.move(to: center)
                    path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                    path.closeSubpath()
                    canvas.fill(path, with: .color(color.opacity(0.13)))
                }
            }
        }
        .mask(
            RadialGradient(colors: [.black, .clear], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 60, endRadius: 560)
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small, fast, repeatable random number generator (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
