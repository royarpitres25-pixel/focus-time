import SwiftUI
import WidgetKit

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let totals: DayTotals
    /// The active session as it will look at `date`.
    let session: ActiveSession?

    static let preview = TodayEntry(
        date: .now,
        totals: DayTotals(seconds: 50 * 60, sessions: 2),
        session: nil
    )
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
        } else {
            completion(TodayTimeline.entries(now: .now).first ?? .preview)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let entries = TodayTimeline.entries(now: now)
        completion(Timeline(entries: entries, policy: .after(TodayTimeline.startOfTomorrow(after: now))))
    }
}

enum TodayTimeline {
    /// One entry now, one when the running countdown ends (so a focus that
    /// finishes while the app is asleep still shows up in today's total), and
    /// one at midnight to reset the day.
    static func entries(now: Date, calendar: Calendar = .current) -> [TodayEntry] {
        let summaries = SharedStore.summaries(since: calendar.startOfDay(for: now))
        let session = ActiveSessionStore().load()

        var dates = [now]
        if let end = session?.runningEndDate, end > now {
            dates.append(end)
        }
        dates.append(startOfTomorrow(after: now, calendar: calendar))

        return dates.sorted().map { date in
            entry(at: date, summaries: summaries, session: session, calendar: calendar)
        }
    }

    static func entry(at date: Date, summaries: [FocusSummary], session: ActiveSession?, calendar: Calendar) -> TodayEntry {
        var all = summaries
        var projected = session
        if let session {
            var machine = FocusMachine(session: session)
            for event in machine.refresh(now: date) {
                if case .focusCompleted(let focus) = event, !all.contains(where: { $0.id == focus.id }) {
                    all.append(FocusSummary(focus))
                }
            }
            projected = machine.session
        }
        return TodayEntry(
            date: date,
            totals: FocusStats.totals(on: date, from: all, calendar: calendar),
            session: projected
        )
    }

    static func startOfTomorrow(after date: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? date.addingTimeInterval(86_400)
    }
}

// MARK: - Widget

struct TodayProgressWidget: Widget {
    let kind = "TodayProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
                .widgetURL(DeepLink.focus)
        }
        .configurationDisplayName("Today's Focus")
        .description("Minutes focused today, and the session in progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetBackground: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper
            RetroStripes(thickness: 4, spacing: 2)
        }
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 16) {
                TodayStatsView(totals: entry.totals, session: nil)
                Rectangle()
                    .fill(Theme.ink.opacity(0.12))
                    .frame(width: 1)
                    .padding(.vertical, 4)
                SessionPanel(session: entry.session)
            }
            .padding(.bottom, 6)
        default:
            TodayStatsView(totals: entry.totals, session: entry.session)
                .padding(.bottom, 6)
        }
    }
}

/// "TODAY · 50 minutes focused", plus a session dot per completed focus.
struct TodayStatsView: View {
    let totals: DayTotals
    /// Shown as a one-line status at the bottom when there's no room for a panel.
    let session: ActiveSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY")
                .font(.retroLabel(.caption2))
                .tracking(2)
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 4)
            Text("\(totals.minutes)")
                .font(.system(size: 48, weight: .black, design: .serif))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .widgetAccentable()
            Text(totals.minutes == 1 ? "minute focused" : "minutes focused")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 6)
            if let session, session.stage != .breakDone {
                StatusLine(session: session)
            } else {
                SessionDots(count: totals.sessions, size: 7)
                    .widgetAccentable()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A compact line such as "● 12:34 left".
struct StatusLine: View {
    let session: ActiveSession

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.accent(for: session.stage))
                .frame(width: 7, height: 7)
            switch session.stage {
            case .focusing, .onBreak:
                if let end = session.endDate {
                    Text(timerInterval: end.addingTimeInterval(-session.phaseDuration)...end, countsDown: true, showsHours: false)
                        .monospacedDigit()
                }
            default:
                Text(session.stage.label)
            }
        }
        .font(.retroLabel(.caption))
        .foregroundStyle(Theme.ink)
    }
}

/// Right side of the medium widget: the session in progress, or an invitation to start.
struct SessionPanel: View {
    let session: ActiveSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let session, session.stage != .breakDone {
                Label(session.stage.label.uppercased(), systemImage: session.stage.symbol)
                    .font(.retroLabel(.caption2))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accentText(for: session.stage))
                    .lineLimit(1)
                Text(session.name)
                    .font(.retroDisplay(.headline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Spacer(minLength: 2)
                CountdownTile(session: session)
            } else {
                Text("READY")
                    .font(.retroLabel(.caption2))
                    .tracking(2)
                    .foregroundStyle(Theme.tomatoText)
                Text("Tap to start a focus")
                    .font(.retroDisplay(.headline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Spacer(minLength: 2)
                CountdownTile(session: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small flip-clock tile, matching the big clock in the app.
struct CountdownTile: View {
    let session: ActiveSession?

    var body: some View {
        content
            .font(.clockDigits(size: 26))
            .monospacedDigit()
            .foregroundStyle(Theme.tileText)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { FlipTileBackground(cornerRadius: 10) }
    }

    @ViewBuilder private var content: some View {
        if let session {
            switch session.stage {
            case .focusing, .onBreak:
                if let end = session.endDate {
                    Text(timerInterval: end.addingTimeInterval(-session.phaseDuration)...end, countsDown: true, showsHours: false)
                        .multilineTextAlignment(.leading)
                        .frame(width: 76, alignment: .leading)
                }
            case .paused:
                Text(Duration.seconds((session.pausedRemaining ?? 0).rounded(.up)).formatted(.time(pattern: .minuteSecond)))
            case .focusDone, .breakDone, .idle:
                Image(systemName: "checkmark")
                    .fontWeight(.heavy)
            }
        } else {
            Text("25:00")
        }
    }
}

#Preview(as: .systemSmall) {
    TodayProgressWidget()
} timeline: {
    TodayEntry.preview
}

#Preview(as: .systemMedium) {
    TodayProgressWidget()
} timeline: {
    TodayEntry.preview
    TodayEntry(
        date: .now,
        totals: DayTotals(seconds: 25 * 60, sessions: 1),
        session: ActiveSession(
            id: UUID(),
            name: "Read chapter 4",
            phase: .focus,
            focusDuration: 25 * 60,
            breakDuration: 5 * 60,
            startedAt: .now,
            endDate: .now.addingTimeInterval(18 * 60),
            pausedRemaining: nil,
            focusCompletedAt: nil
        )
    )
}
