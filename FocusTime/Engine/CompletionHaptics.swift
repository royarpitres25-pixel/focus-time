import CoreHaptics
import Foundation

/// The reward for finishing a focus: three rising taps, a warm swell that
/// fades out, and one bright tap at the end.
@MainActor
final class CompletionHaptics {
    static let shared = CompletionHaptics()

    private var engine: CHHapticEngine?

    private init() {}

    func play() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try preparedEngine()
            try engine.start()
            let player = try engine.makePlayer(with: Self.pattern())
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a nicety; never let them interrupt the flow.
        }
    }

    private func preparedEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        let engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = true
        engine.playsHapticsOnly = true
        engine.resetHandler = { [weak engine] in
            try? engine?.start()
        }
        self.engine = engine
        return engine
    }

    private static func pattern() throws -> CHHapticPattern {
        func tap(_ time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: time
            )
        }

        let swellStart: TimeInterval = 0.36
        let swell = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
            ],
            relativeTime: swellStart,
            duration: 0.6
        )
        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 1),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.15, value: 0.8),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.6, value: 0),
            ],
            relativeTime: swellStart
        )

        return try CHHapticPattern(
            events: [
                tap(0, intensity: 0.45, sharpness: 0.35),
                tap(0.12, intensity: 0.65, sharpness: 0.45),
                tap(0.24, intensity: 0.9, sharpness: 0.55),
                swell,
                tap(1.05, intensity: 0.55, sharpness: 0.85),
            ],
            parameterCurves: [fade]
        )
    }
}
