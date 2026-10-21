import Foundation

/// The parts of a completed focus that totals need.
struct FocusSummary: Equatable, Sendable {
    var id: UUID
    var completedAt: Date
    var duration: TimeInterval

    init(id: UUID, completedAt: Date, duration: TimeInterval) {
        self.id = id
        self.completedAt = completedAt
        self.duration = duration
    }

    init(_ focus: CompletedFocus) {
        self.init(id: focus.id, completedAt: focus.completedAt, duration: focus.duration)
    }
}

struct DayTotals: Equatable, Sendable {
    var seconds: TimeInterval = 0
    var sessions = 0

    var minutes: Int { Int(seconds / 60) }
}

enum FocusStats {
    /// Completed focus time for the calendar day containing `day`.
    /// Only focus sessions are ever recorded, so breaks can't be counted.
    static func totals(on day: Date, from summaries: [FocusSummary], calendar: Calendar = .current) -> DayTotals {
        summaries.reduce(into: DayTotals()) { totals, summary in
            guard calendar.isDate(summary.completedAt, inSameDayAs: day) else { return }
            totals.seconds += summary.duration
            totals.sessions += 1
        }
    }
}

enum DurationText {
    /// "25 min", or "15 sec" for the short development timers.
    static func short(_ interval: TimeInterval) -> String {
        if interval >= 60 {
            return "\(Int((interval / 60).rounded())) min"
        }
        return "\(Int(interval.rounded())) sec"
    }
}
