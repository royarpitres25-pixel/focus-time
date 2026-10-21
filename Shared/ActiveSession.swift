import Foundation

/// What the person sees: one of six moments in a focus round.
enum FocusStage: String, Codable, Hashable, Sendable {
    case idle
    case focusing
    case paused
    case focusDone
    case onBreak
    case breakDone

    var isRunning: Bool { self == .focusing || self == .onBreak }
    var isBreak: Bool { self == .onBreak || self == .breakDone }

    var label: String {
        switch self {
        case .idle: "Ready"
        case .focusing: "Focusing"
        case .paused: "Paused"
        case .focusDone: "Focus complete"
        case .onBreak: "On a break"
        case .breakDone: "Break's over"
        }
    }

    var symbol: String {
        switch self {
        case .idle, .focusing: "timer"
        case .paused: "pause.fill"
        case .focusDone: "checkmark.seal.fill"
        case .onBreak: "cup.and.saucer.fill"
        case .breakDone: "bell.fill"
        }
    }
}

/// The one session that can be active at a time.
///
/// Time is stored as an end date rather than a ticking counter, so the
/// remaining time is always right — after the phone sleeps, the app is
/// suspended, or the app is relaunched.
struct ActiveSession: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        case focus
        case focusDone
        case rest
        case restDone
    }

    var id: UUID
    var name: String
    var phase: Phase
    var focusDuration: TimeInterval
    var breakDuration: TimeInterval
    /// When the focus first started (pauses don't move it).
    var startedAt: Date
    /// When the current running phase ends. `nil` while paused or finished.
    var endDate: Date?
    /// Time left on a paused focus. `nil` unless paused.
    var pausedRemaining: TimeInterval?
    /// When the focus part finished.
    var focusCompletedAt: Date?

    var stage: FocusStage {
        switch phase {
        case .focus: pausedRemaining == nil ? FocusStage.focusing : FocusStage.paused
        case .focusDone: .focusDone
        case .rest: .onBreak
        case .restDone: .breakDone
        }
    }

    /// Length of the phase on screen right now.
    var phaseDuration: TimeInterval {
        switch phase {
        case .focus, .focusDone: focusDuration
        case .rest, .restDone: breakDuration
        }
    }

    /// End date of a phase that is currently counting down.
    var runningEndDate: Date? {
        pausedRemaining == nil ? endDate : nil
    }

    func remaining(at date: Date) -> TimeInterval {
        switch phase {
        case .focus, .rest:
            if let pausedRemaining { return pausedRemaining }
            guard let endDate else { return 0 }
            return max(0, endDate.timeIntervalSince(date))
        case .focusDone, .restDone:
            return 0
        }
    }

    /// 0 at the start of a phase, 1 at the end.
    func progress(at date: Date) -> Double {
        guard phaseDuration > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: date) / phaseDuration))
    }
}

/// A finished focus, ready to be saved to history.
struct CompletedFocus: Equatable, Sendable {
    var id: UUID
    var name: String
    var startedAt: Date
    var completedAt: Date
    var duration: TimeInterval
}

/// Saves the active session so it survives relaunches. Lives in the App Group
/// so the widget can show the session too.
struct ActiveSessionStore {
    static let key = "activeSession.v1"

    var defaults: UserDefaults = AppGroup.defaults

    func load() -> ActiveSession? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(ActiveSession.self, from: data)
    }

    func save(_ session: ActiveSession?) {
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}
