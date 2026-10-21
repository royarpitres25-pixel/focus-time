import ActivityKit
import Foundation

/// The Live Activity shown on the Lock Screen and in the Dynamic Island.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stage: FocusStage
        /// Start of the countdown window (end minus the phase length).
        var startDate: Date
        var endDate: Date
        var pausedRemaining: TimeInterval?
        var duration: TimeInterval

        var timerRange: ClosedRange<Date> { startDate...endDate }
    }

    var sessionID: UUID
    var sessionName: String
}

extension FocusActivityAttributes.ContentState {
    init(session: ActiveSession, now: Date) {
        let duration = session.phaseDuration
        let stage = session.stage
        let end: Date
        switch stage {
        case .focusing, .onBreak:
            end = session.endDate ?? now
        case .paused:
            end = now.addingTimeInterval(session.pausedRemaining ?? 0)
        case .idle, .focusDone, .breakDone:
            end = now
        }
        self.init(
            stage: stage,
            startDate: end.addingTimeInterval(-duration),
            endDate: end,
            pausedRemaining: session.pausedRemaining,
            duration: duration
        )
    }

    /// The stage to show, treating a countdown that has run out as finished
    /// even before the app gets a chance to update the activity.
    func displayStage(isStale: Bool, now: Date = .now) -> FocusStage {
        guard stage.isRunning, isStale || endDate <= now else { return stage }
        return stage == .focusing ? .focusDone : .breakDone
    }
}
