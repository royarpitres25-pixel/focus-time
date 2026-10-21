import Foundation

/// The rules of a focus round, with no UI or side effects so they can be tested.
///
/// idle → focusing ⇄ paused → focusDone → onBreak → breakDone → idle
///
/// - Only one session can be active.
/// - Cancelling a focus discards it; nothing is recorded.
/// - The break never starts on its own.
/// - Only completed focus time is reported; breaks never count.
struct FocusMachine: Sendable {
    enum Failure: Error, Equatable {
        case sessionAlreadyActive
        case emptyName
        case invalidTransition
    }

    enum Event: Equatable, Sendable {
        case focusCompleted(CompletedFocus)
        case breakCompleted
    }

    static let maxNameLength = 60

    private(set) var session: ActiveSession?

    init(session: ActiveSession? = nil) {
        self.session = session
    }

    var stage: FocusStage { session?.stage ?? .idle }

    mutating func startFocus(
        name: String,
        focusDuration: TimeInterval,
        breakDuration: TimeInterval,
        now: Date,
        id: UUID = UUID()
    ) throws {
        switch stage {
        case .idle, .focusDone, .breakDone:
            break
        case .focusing, .paused, .onBreak:
            throw Failure.sessionAlreadyActive
        }
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
        guard !trimmed.isEmpty else { throw Failure.emptyName }

        session = ActiveSession(
            id: id,
            name: trimmed,
            phase: .focus,
            focusDuration: focusDuration,
            breakDuration: breakDuration,
            startedAt: now,
            endDate: now.addingTimeInterval(focusDuration),
            pausedRemaining: nil,
            focusCompletedAt: nil
        )
    }

    mutating func pause(now: Date) throws {
        guard var current = session, current.stage == .focusing, let end = current.endDate, end > now else {
            throw Failure.invalidTransition
        }
        current.pausedRemaining = end.timeIntervalSince(now)
        current.endDate = nil
        session = current
    }

    mutating func resume(now: Date) throws {
        guard var current = session, current.stage == .paused, let remaining = current.pausedRemaining else {
            throw Failure.invalidTransition
        }
        current.endDate = now.addingTimeInterval(remaining)
        current.pausedRemaining = nil
        session = current
    }

    /// Stops a focus without recording it.
    mutating func cancel() throws {
        guard stage == .focusing || stage == .paused else { throw Failure.invalidTransition }
        session = nil
    }

    mutating func startBreak(now: Date) throws {
        guard var current = session, current.stage == .focusDone else { throw Failure.invalidTransition }
        current.phase = .rest
        current.endDate = now.addingTimeInterval(current.breakDuration)
        current.pausedRemaining = nil
        session = current
    }

    /// Ends a break early.
    mutating func endBreak() throws {
        guard var current = session, current.stage == .onBreak else { throw Failure.invalidTransition }
        current.phase = .restDone
        current.endDate = nil
        session = current
    }

    /// Clears a finished round and returns to idle.
    mutating func finish() throws {
        guard stage == .focusDone || stage == .breakDone else { throw Failure.invalidTransition }
        session = nil
    }

    /// Moves a running phase forward when its end date has passed.
    /// The completion time is the scheduled end, not when the app noticed,
    /// so a focus that finished while the app was closed is recorded correctly.
    mutating func refresh(now: Date) -> [Event] {
        guard var current = session, let end = current.runningEndDate, end <= now else { return [] }
        switch current.phase {
        case .focus:
            current.phase = .focusDone
            current.endDate = nil
            current.focusCompletedAt = end
            session = current
            return [.focusCompleted(CompletedFocus(
                id: current.id,
                name: current.name,
                startedAt: current.startedAt,
                completedAt: end,
                duration: current.focusDuration
            ))]
        case .rest:
            current.phase = .restDone
            current.endDate = nil
            session = current
            return [.breakCompleted]
        case .focusDone, .restDone:
            return []
        }
    }
}
