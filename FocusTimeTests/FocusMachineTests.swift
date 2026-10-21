import Foundation
import Testing
@testable import FocusTime

@Suite("Focus rules")
struct FocusMachineTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let focus: TimeInterval = 25 * 60
    let rest: TimeInterval = 5 * 60

    private func started(_ name: String = "Read chapter 4") throws -> FocusMachine {
        var machine = FocusMachine()
        try machine.startFocus(name: name, focusDuration: focus, breakDuration: rest, now: t0)
        return machine
    }

    @Test func startsA25MinuteFocus() throws {
        let machine = try started("  Read chapter 4  ")
        #expect(machine.stage == .focusing)
        #expect(machine.session?.name == "Read chapter 4")
        #expect(machine.session?.remaining(at: t0.addingTimeInterval(60)) == focus - 60)
    }

    @Test func rejectsAnEmptyName() {
        var machine = FocusMachine()
        #expect(throws: FocusMachine.Failure.emptyName) {
            try machine.startFocus(name: "   ", focusDuration: focus, breakDuration: rest, now: t0)
        }
        #expect(machine.session == nil)
    }

    @Test func onlyOneSessionCanBeActive() throws {
        var machine = try started()
        #expect(throws: FocusMachine.Failure.sessionAlreadyActive) {
            try machine.startFocus(name: "Something else", focusDuration: focus, breakDuration: rest, now: t0)
        }
        #expect(machine.session?.name == "Read chapter 4")
    }

    @Test func pauseFreezesTheClockAndResumeContinuesIt() throws {
        var machine = try started()
        try machine.pause(now: t0.addingTimeInterval(600))
        #expect(machine.stage == .paused)
        // Time passing while paused changes nothing.
        #expect(machine.session?.remaining(at: t0.addingTimeInterval(5000)) == focus - 600)
        #expect(machine.refresh(now: t0.addingTimeInterval(5000)).isEmpty)

        try machine.resume(now: t0.addingTimeInterval(1000))
        #expect(machine.stage == .focusing)
        #expect(machine.session?.endDate == t0.addingTimeInterval(1000 + focus - 600))
    }

    @Test func cancelDiscardsWithoutRecording() throws {
        var machine = try started()
        try machine.cancel()
        #expect(machine.session == nil)
        #expect(machine.refresh(now: t0.addingTimeInterval(focus * 2)).isEmpty)
    }

    @Test func completionUsesTheScheduledEndTime() throws {
        var machine = try started()
        let events = machine.refresh(now: t0.addingTimeInterval(focus + 3600))
        #expect(machine.stage == .focusDone)
        #expect(events == [.focusCompleted(CompletedFocus(
            id: machine.session!.id,
            name: "Read chapter 4",
            startedAt: t0,
            completedAt: t0.addingTimeInterval(focus),
            duration: focus
        ))])
        // Completing is reported once.
        #expect(machine.refresh(now: t0.addingTimeInterval(focus + 7200)).isEmpty)
    }

    @Test func breakStartsOnlyWhenAsked() throws {
        var machine = try started()
        _ = machine.refresh(now: t0.addingTimeInterval(focus))
        // Hours later, still waiting for the person to start the break.
        #expect(machine.refresh(now: t0.addingTimeInterval(focus + 3 * 3600)).isEmpty)
        #expect(machine.stage == .focusDone)

        let breakStart = t0.addingTimeInterval(focus + 100)
        try machine.startBreak(now: breakStart)
        #expect(machine.stage == .onBreak)
        #expect(machine.session?.remaining(at: breakStart) == rest)

        #expect(machine.refresh(now: breakStart.addingTimeInterval(rest)) == [.breakCompleted])
        #expect(machine.stage == .breakDone)
    }

    @Test func breaksAreNotCountedAsFocus() throws {
        var machine = try started()
        var summaries: [FocusSummary] = []
        for event in machine.refresh(now: t0.addingTimeInterval(focus)) {
            if case .focusCompleted(let done) = event { summaries.append(FocusSummary(done)) }
        }
        try machine.startBreak(now: t0.addingTimeInterval(focus))
        for event in machine.refresh(now: t0.addingTimeInterval(focus + rest)) {
            if case .focusCompleted(let done) = event { summaries.append(FocusSummary(done)) }
        }
        let totals = FocusStats.totals(on: t0, from: summaries)
        #expect(totals.sessions == 1)
        #expect(totals.minutes == 25)
    }

    @Test func activeTimerSurvivesARelaunch() throws {
        let machine = try started()
        let data = try JSONEncoder().encode(machine.session)
        let restored = try JSONDecoder().decode(ActiveSession.self, from: data)

        var relaunched = FocusMachine(session: restored)
        #expect(relaunched.session?.remaining(at: t0.addingTimeInterval(300)) == focus - 300)

        // The focus ended while the app was closed: it's recorded on relaunch.
        let events = relaunched.refresh(now: t0.addingTimeInterval(focus + 60))
        #expect(events.count == 1)
        #expect(relaunched.stage == .focusDone)
    }

    @Test func focusAgainAfterABreak() throws {
        var machine = try started()
        _ = machine.refresh(now: t0.addingTimeInterval(focus))
        try machine.startBreak(now: t0.addingTimeInterval(focus))
        try machine.endBreak()
        #expect(machine.stage == .breakDone)
        let firstID = machine.session?.id

        try machine.startFocus(name: "Read chapter 4", focusDuration: focus, breakDuration: rest, now: t0.addingTimeInterval(2000))
        #expect(machine.stage == .focusing)
        #expect(machine.session?.id != firstID)
    }

    @Test func invalidTransitionsAreRejected() throws {
        var idle = FocusMachine()
        #expect(throws: FocusMachine.Failure.invalidTransition) { try idle.pause(now: t0) }
        #expect(throws: FocusMachine.Failure.invalidTransition) { try idle.startBreak(now: t0) }

        var focusing = try started()
        #expect(throws: FocusMachine.Failure.invalidTransition) { try focusing.startBreak(now: t0) }
        #expect(throws: FocusMachine.Failure.invalidTransition) { try focusing.finish() }
    }
}

@Suite("Daily totals")
struct FocusStatsTests {
    @Test func countsOnlyTheGivenDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 15))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let summaries = [
            FocusSummary(id: UUID(), completedAt: today, duration: 1500),
            FocusSummary(id: UUID(), completedAt: today.addingTimeInterval(-3600), duration: 1500),
            FocusSummary(id: UUID(), completedAt: yesterday, duration: 1500),
        ]

        let totals = FocusStats.totals(on: today, from: summaries, calendar: calendar)
        #expect(totals.sessions == 2)
        #expect(totals.minutes == 50)
    }
}
