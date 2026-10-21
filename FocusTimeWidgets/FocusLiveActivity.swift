import ActivityKit
import SwiftUI
import WidgetKit

/// The current session and its countdown on the Lock Screen and in the Dynamic Island.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(
                name: context.attributes.sessionName,
                state: context.state,
                stage: context.state.displayStage(isStale: context.isStale)
            )
            .activityBackgroundTint(Theme.paper)
            .activitySystemActionForegroundColor(Theme.ink)
            .widgetURL(DeepLink.focus)
        } dynamicIsland: { context in
            let stage = context.state.displayStage(isStale: context.isStale)
            let accent = Theme.accent(for: stage)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(stage.label.uppercased(), systemImage: stage.symbol)
                        .font(.retroLabel(.caption2))
                        .tracking(1.2)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveCountdown(state: context.state, stage: stage)
                        .font(.clockDigits(size: 28))
                        .foregroundStyle(accent)
                        .frame(maxWidth: 96, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.attributes.sessionName)
                            .font(.retroDisplay(.headline))
                            .lineLimit(1)
                        LiveProgress(state: context.state, stage: stage)
                            .tint(accent)
                        RetroStripes(thickness: 3, spacing: 2)
                            .frame(maxWidth: 60)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: stage.symbol)
                    .foregroundStyle(accent)
            } compactTrailing: {
                LiveCountdown(state: context.state, stage: stage)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(maxWidth: 52)
            } minimal: {
                LiveRing(state: context.state, stage: stage)
                    .tint(accent)
            }
            .widgetURL(DeepLink.focus)
            .keylineTint(accent)
        }
    }
}

// MARK: - Lock Screen

struct FocusLockScreenView: View {
    let name: String
    let state: FocusActivityAttributes.ContentState
    let stage: FocusStage

    var body: some View {
        HStack(spacing: 14) {
            RetroStripes(axis: .vertical, thickness: 5, spacing: 3)
                .frame(width: 21, height: 70)
            VStack(alignment: .leading, spacing: 6) {
                Label(stage.label.uppercased(), systemImage: stage.symbol)
                    .font(.retroLabel(.caption2))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accentText(for: stage))
                Text(name)
                    .font(.retroDisplay(.title3))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if stage == .focusDone {
                    Text("Open Focus Time to start your break")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    LiveProgress(state: state, stage: stage)
                        .tint(Theme.accent(for: stage))
                }
            }
            Spacer(minLength: 8)
            LiveCountdown(state: state, stage: stage)
                .font(.clockDigits(size: 34))
                .foregroundStyle(Theme.tileText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 96)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background { FlipTileBackground(cornerRadius: 14) }
        }
        .padding(16)
    }
}

// MARK: - Pieces

/// Counts down on its own; no app updates needed while it runs.
struct LiveCountdown: View {
    let state: FocusActivityAttributes.ContentState
    let stage: FocusStage

    var body: some View {
        switch stage {
        case .focusing, .onBreak:
            Text(timerInterval: state.timerRange, countsDown: true, showsHours: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        case .paused:
            Text(Duration.seconds((state.pausedRemaining ?? 0).rounded(.up)).formatted(.time(pattern: .minuteSecond)))
                .monospacedDigit()
        case .idle, .focusDone, .breakDone:
            Image(systemName: "checkmark")
                .fontWeight(.heavy)
        }
    }
}

struct LiveProgress: View {
    let state: FocusActivityAttributes.ContentState
    let stage: FocusStage

    var body: some View {
        switch stage {
        case .focusing, .onBreak:
            ProgressView(timerInterval: state.timerRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        case .paused:
            ProgressView(value: 1 - (state.pausedRemaining ?? 0) / max(state.duration, 1))
        case .idle, .focusDone, .breakDone:
            ProgressView(value: 1)
        }
    }
}

struct LiveRing: View {
    let state: FocusActivityAttributes.ContentState
    let stage: FocusStage

    var body: some View {
        switch stage {
        case .focusing, .onBreak:
            ProgressView(timerInterval: state.timerRange, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
        case .paused:
            Image(systemName: "pause.fill")
        case .idle, .focusDone, .breakDone:
            Image(systemName: "checkmark")
        }
    }
}

#Preview("Lock Screen", as: .content, using: FocusActivityAttributes(sessionID: UUID(), sessionName: "Read chapter 4")) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState(
        stage: .focusing,
        startDate: .now.addingTimeInterval(-7 * 60),
        endDate: .now.addingTimeInterval(18 * 60),
        pausedRemaining: nil,
        duration: 25 * 60
    )
    FocusActivityAttributes.ContentState(
        stage: .paused,
        startDate: .now,
        endDate: .now.addingTimeInterval(12 * 60),
        pausedRemaining: 12 * 60,
        duration: 25 * 60
    )
}
