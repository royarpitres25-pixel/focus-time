import SwiftUI

/// The live clock and progress bar. Remaining time is computed from the
/// session's end date on every tick, so it can never drift.
struct ClockArea: View {
    @Environment(FocusEngine.self) private var engine
    let accent: Color

    var body: some View {
        let session = engine.session
        TimelineView(.periodic(from: anchor(for: session), by: 1)) { context in
            let remaining = session?.remaining(at: context.date) ?? engine.focusDuration
            let progress = session?.progress(at: context.date) ?? 0
            VStack(spacing: 22) {
                FlipClock(
                    seconds: Int(remaining.rounded(.up)),
                    accent: accent,
                    isRunning: engine.stage.isRunning,
                    isDimmed: engine.stage == .paused
                )
                SegmentBar(progress: progress, accent: accent)
            }
            .frame(maxWidth: 620)
        }
    }

    /// Ticks line up with whole seconds left, so the digits change on time.
    private func anchor(for session: ActiveSession?) -> Date {
        guard let session, let end = session.runningEndDate else { return .now }
        return end.addingTimeInterval(-session.phaseDuration)
    }
}

/// A four-digit flip clock (MM:SS) that scales to the space it's given.
struct FlipClock: View {
    let seconds: Int
    let accent: Color
    var isRunning = false
    var isDimmed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let minutes = min(seconds / 60, 99)
        let secs = seconds % 60
        let digits = [minutes / 10, minutes % 10, secs / 10, secs % 10]

        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let tileWidth = width * 0.205
            let digitOpacity = isDimmed ? 0.45 : 1.0
            HStack(spacing: width * 0.025) {
                FlipDigit(digit: digits[0], width: tileWidth, height: height, digitOpacity: digitOpacity)
                FlipDigit(digit: digits[1], width: tileWidth, height: height, digitOpacity: digitOpacity)
                ClockColon(
                    width: width * 0.08,
                    height: height,
                    color: accent,
                    isLit: !isRunning || seconds.isMultiple(of: 2)
                )
                FlipDigit(digit: digits[2], width: tileWidth, height: height, digitOpacity: digitOpacity)
                FlipDigit(digit: digits[3], width: tileWidth, height: height, digitOpacity: digitOpacity)
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(2.6, contentMode: .fit)
        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: seconds)
        .animation(.easeInOut(duration: 0.4), value: isDimmed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(minutes: minutes, seconds: secs))
    }

    private func accessibilityText(minutes: Int, seconds: Int) -> String {
        var parts: [String] = []
        if minutes > 0 { parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes") }
        if seconds > 0 || minutes == 0 { parts.append(seconds == 1 ? "1 second" : "\(seconds) seconds") }
        return parts.joined(separator: " ") + " remaining"
    }
}

struct FlipDigit: View {
    let digit: Int
    let width: CGFloat
    let height: CGFloat
    var digitOpacity: Double = 1

    var body: some View {
        ZStack {
            FlipTileBackground(cornerRadius: width * 0.16)
            Text("\(digit)")
                .font(.clockDigits(size: height * 0.68))
                .foregroundStyle(Theme.tileText.opacity(digitOpacity))
                .contentTransition(.numericText(countsDown: true))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            // The hinge line sits on top of the digit, like a real flip clock.
            Rectangle()
                .fill(Theme.tile.opacity(0.85))
                .frame(height: max(1.5, height * 0.014))
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.22), radius: width * 0.05, y: width * 0.04)
    }
}

struct ClockColon: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    var isLit: Bool

    var body: some View {
        VStack(spacing: height * 0.2) {
            Circle().fill(color)
            Circle().fill(color)
        }
        .frame(width: width * 0.55)
        .frame(width: width, height: height)
        .opacity(isLit ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.45), value: isLit)
    }
}

/// A retro VU-meter style bar: one segment per minute of a 25-minute focus.
struct SegmentBar: View {
    let progress: Double
    let accent: Color
    var segments = 25

    var body: some View {
        let filled = Int((progress * Double(segments)).rounded(.down))
        HStack(spacing: 4) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < filled ? accent : Theme.ink.opacity(0.12))
            }
        }
        .frame(height: 10)
        .animation(.easeOut(duration: 0.5), value: filled)
        .accessibilityHidden(true)
    }
}
