import ActivityKit
import Foundation

/// Keeps one Live Activity in step with the active session. Updates are local
/// only. The countdown runs on its own with `Text(timerInterval:)`, so no
/// server and no push notifications are needed.
@MainActor
enum LiveActivitySync {
    static func sync(with session: ActiveSession?, now: Date) {
        let activities = Activity<FocusActivityAttributes>.activities

        // Only the current session gets an activity.
        for activity in activities where activity.attributes.sessionID != session?.id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        guard let session else { return }

        let state = FocusActivityAttributes.ContentState(session: session, now: now)
        // Marked stale when the countdown ends, so the activity can show "time's up"
        // even if the app is suspended.
        let content = ActivityContent(state: state, staleDate: session.runningEndDate)

        let live = activities.first { activity in
            activity.attributes.sessionID == session.id
                && (activity.activityState == .active || activity.activityState == .stale)
        }

        if let live {
            if session.stage == .breakDone {
                Task { await live.end(content, dismissalPolicy: .after(now.addingTimeInterval(15 * 60))) }
            } else {
                Task { await live.update(content) }
            }
        } else if session.stage != .breakDone, ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity<FocusActivityAttributes>.request(
                attributes: FocusActivityAttributes(sessionID: session.id, sessionName: session.name),
                content: content,
                pushType: nil
            )
        }
    }
}
