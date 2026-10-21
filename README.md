# Focus Time

A calm, retro focus timer for iPhone. Name what you're working on, focus for 25 minutes, then take a 5-minute break when you're ready.

Everything stays on the phone. There are no accounts, no servers, no analytics and no third-party code. The app only uses Apple frameworks: SwiftUI, SwiftData, WidgetKit, ActivityKit, Core Haptics and UserNotifications.

## Requirements

- iOS 26 or later, because the app uses Liquid Glass.
- Xcode 26 or later. Xcode 27.1 is recommended: it adds the iPhone Duo simulator and lets the app use the Duo's full screen.

## Run it

1. Open `FocusTime.xcodeproj`.
2. Select the **FocusTime** target, open **Signing & Capabilities**, and choose your Team. Repeat this for **FocusTimeWidgets**.
3. If Xcode says the bundle ID or App Group is taken, change `com.arpitroy.focustime` to your own prefix in both targets. Then update the App Group in `Config/*.entitlements` and in `Shared/AppGroup.swift` to match.
4. Choose an iPhone or the iPhone Duo simulator and press Run.

### Short test timers

Debug builds have a hammer menu at the top of the Focus screen. Turn on **Short Test Timers** to get a 15-second focus and a 10-second break. You can also pass `-useTestTimers YES` as a launch argument. Release builds leave out the menu and the short timers.

### Tests

Press Cmd+U.

- **FocusTimeTests** cover the timer rules:
  - only one active session at a time
  - pause and resume
  - cancel saves nothing
  - the break only starts when you start it
  - breaks don't count toward focus time
  - a running timer is restored after a relaunch
  - daily totals
- **FocusTimeUITests** play through real sessions with the short timers:
  - a full focus and break that shows up in History
  - a cancelled focus that doesn't show up
  - a timer restored after a relaunch
  - the Live Activity on the Home Screen and Lock Screen

  To save a screenshot of each step, set `TEST_RUNNER_FT_SHOTS=/some/folder` when you run `xcodebuild test`.

## How it works

| Piece | Where |
|---|---|
| Timer rules (start, pause, cancel, break, completion) | `Shared/FocusMachine.swift` |
| Active session, saved so it survives relaunch | `Shared/ActiveSession.swift` |
| Completed sessions (SwiftData, in the App Group) | `Shared/FocusRecord.swift` |
| Runs the session, haptics, notifications, widget reloads | `FocusTime/Engine/` |
| Focus and History screens | `FocusTime/Views/` |
| Home Screen widget and Live Activity | `FocusTimeWidgets/` |
| Retro palette, type and stripes | `Shared/Theme.swift`, `Shared/RetroComponents.swift` |

- **The timer can't drift.** It stores an end date instead of counting seconds, so it stays correct when the app is closed, the phone is locked, or the app is relaunched.
- **The Lock Screen and Dynamic Island count down without the app.** They use `Text(timerInterval:)`, so no server or push notifications are needed.
- **Only completed focus time is saved.** Cancelled sessions and breaks never count toward your totals. A focus that ends while the app is closed is still recorded, at the time it actually ended.
- **The widget shows the same thing.** It reads the same on-device store as the app, opens the Focus screen when tapped, and counts a focus that finished while the app was asleep.
- **It adapts to every screen.** Layouts use size classes, not device checks. On the open iPhone Duo, or in Split View, the tabs become a sidebar. With little height, such as a phone in landscape, the clock and controls sit side by side.
