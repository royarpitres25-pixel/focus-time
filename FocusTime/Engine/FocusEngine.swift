import Foundation
import Observation
import SwiftData
import UIKit
import WidgetKit

/// Focus and break lengths.
enum FocusDurations {
    static let focus: TimeInterval = 25 * 60
    static let rest: TimeInterval = 5 * 60

    /// Short timers for trying the whole flow quickly. Debug builds only.
    static let testFocus: TimeInterval = 15
    static let testRest: TimeInterval = 10

    static var testTimersAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

/// Runs the one active focus session: applies `FocusMachine` rules, saves
/// state on the device, records completed focus, and keeps notifications,
/// the Live Activity, and the widget in step.
@MainActor
@Observable
final class FocusEngine {
    private enum Keys {
        static let lastName = "lastSessionName"
        static let testTimers = "useTestTimers"
    }

    private(set) var session: ActiveSession?
    var draftName: String
    private(set) var useTestDurations: Bool
    /// Goes up each time a focus completes. Views can react to it.
    private(set) var completionCount = 0

    @ObservationIgnored private var machine: FocusMachine
    @ObservationIgnored private let store: ActiveSessionStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private var hasLaunched = false

    init(context: ModelContext, store: ActiveSessionStore = ActiveSessionStore(), defaults: UserDefaults = AppGroup.defaults) {
        let saved = store.load()
        self.context = context
        self.store = store
        self.defaults = defaults
        self.machine = FocusMachine(session: saved)
        self.session = saved
        self.draftName = defaults.string(forKey: Keys.lastName) ?? ""
        self.useTestDurations = FocusDurations.testTimersAvailable && defaults.bool(forKey: Keys.testTimers)

        // Catch up on anything that finished while the app wasn't running.
        // Notifications, the Live Activity and the widget are synced once the
        // first window is active (`sceneDidBecomeActive`): calling those system
        // services this early in launch can block the main thread.
        for event in machine.refresh(now: .now) {
            handle(event)
        }
        session = machine.session
        store.save(session)
        hasLaunched = true
    }

    // MARK: - State

    var stage: FocusStage { session?.stage ?? .idle }

    var focusDuration: TimeInterval {
        useTestDurations ? FocusDurations.testFocus : FocusDurations.focus
    }

    var breakDuration: TimeInterval {
        session?.breakDuration ?? (useTestDurations ? FocusDurations.testRest : FocusDurations.rest)
    }

    var canStart: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    func startFocus() {
        start(named: draftName)
    }

    /// Starts another focus with the same name after a break.
    func focusAgain() {
        start(named: session?.name ?? draftName)
    }

    func pause() { perform { try $0.pause(now: .now) } }
    func resume() { perform { try $0.resume(now: .now) } }
    func cancel() { perform { try $0.cancel() } }
    func startBreak() { perform { try $0.startBreak(now: .now) } }
    func endBreak() { perform { try $0.endBreak() } }
    func finish() { perform { try $0.finish() } }

    func setTestDurations(_ enabled: Bool) {
        guard FocusDurations.testTimersAvailable else { return }
        useTestDurations = enabled
        defaults.set(enabled, forKey: Keys.testTimers)
    }

    func delete(_ records: [FocusRecord]) {
        for record in records {
            context.delete(record)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Call when a window becomes active: catches up on the clock and
    /// re-syncs the Live Activity, notifications and widget.
    func sceneDidBecomeActive() {
        refresh(forceSync: true)
    }

    /// Advances the session if its countdown has run out.
    func refresh() {
        refresh(forceSync: false)
    }

    // MARK: - Internals

    private func start(named name: String) {
        refresh()
        do {
            try machine.startFocus(name: name, focusDuration: focusDuration, breakDuration: currentBreakLength, now: .now)
        } catch {
            return
        }
        if let name = machine.session?.name {
            draftName = name
            defaults.set(name, forKey: Keys.lastName)
        }
        FocusNotifications.requestAuthorization()
        commit()
    }

    private var currentBreakLength: TimeInterval {
        useTestDurations ? FocusDurations.testRest : FocusDurations.rest
    }

    private func perform(_ change: (inout FocusMachine) throws -> Void) {
        refresh()
        do {
            try change(&machine)
        } catch {
            return
        }
        commit()
    }

    private func refresh(forceSync: Bool) {
        let events = machine.refresh(now: .now)
        for event in events {
            handle(event)
        }
        if forceSync || !events.isEmpty {
            commit()
        } else {
            scheduleWakeup()
        }
    }

    private func handle(_ event: FocusMachine.Event) {
        switch event {
        case .focusCompleted(let focus):
            record(focus)
            completionCount += 1
            if hasLaunched, UIApplication.shared.applicationState == .active {
                CompletionHaptics.shared.play()
            }
        case .breakCompleted:
            break
        }
    }

    private func record(_ focus: CompletedFocus) {
        let id = focus.id
        let existing = FetchDescriptor<FocusRecord>(predicate: #Predicate { $0.id == id })
        guard ((try? context.fetchCount(existing)) ?? 0) == 0 else { return }
        context.insert(FocusRecord(
            id: focus.id,
            name: focus.name,
            startedAt: focus.startedAt,
            completedAt: focus.completedAt,
            duration: focus.duration
        ))
        try? context.save()
    }

    /// Publishes the new state everywhere it shows up.
    private func commit() {
        session = machine.session
        store.save(session)
        let now = Date.now
        FocusNotifications.sync(with: session, now: now)
        LiveActivitySync.sync(with: session, now: now)
        WidgetCenter.shared.reloadAllTimelines()
        scheduleWakeup()
    }

    /// Wakes up exactly when the current countdown ends, while the app is open.
    private func scheduleWakeup() {
        wakeTask?.cancel()
        guard let end = machine.session?.runningEndDate else {
            wakeTask = nil
            return
        }
        wakeTask = Task { [weak self] in
            let delay = end.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
