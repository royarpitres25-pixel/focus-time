import Foundation
import UserNotifications

/// Local notifications for when a focus or break ends while the app is in the
/// background. They're scheduled on the device; nothing goes over the network.
enum FocusNotifications {
    private static let identifiers = ["focus.end", "break.end"]

    static func requestAuthorization() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    static func sync(with session: ActiveSession?, now: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard let session, let end = session.runningEndDate, end > now else { return }

        let content = UNMutableNotificationContent()
        let identifier: String
        switch session.phase {
        case .focus:
            identifier = identifiers[0]
            content.title = "Focus complete"
            content.body = "Nice work on \(session.name). Start your break when you're ready."
        case .rest:
            identifier = identifiers[1]
            content.title = "Break's over"
            content.body = "Ready for another round of \(session.name)?"
        case .focusDone, .restDone:
            return
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSince(now)), repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
