import SwiftData
import SwiftUI

/// The main screen: name a session, run the timer, take a break.
/// Every stage has one obvious primary action.
struct FocusScreen: View {
    @Environment(FocusEngine.self) private var engine
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(FocusScreen.recentDescriptor) private var recentRecords: [FocusRecord]
    @FocusState private var nameFieldFocused: Bool
    @State private var confirmingCancel = false
    @State private var nameNudge = 0

    static var recentDescriptor: FetchDescriptor<FocusRecord> {
        var descriptor = FetchDescriptor<FocusRecord>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        descriptor.fetchLimit = 40
        return descriptor
    }

    private var stage: FocusStage { engine.stage }
    private var accent: Color { Theme.accent(for: stage) }

    var body: some View {
        NavigationStack {
            ZStack {
                RetroBackground(accent: accent)

                if stage == .focusDone {
                    Sunburst(color: Theme.mustard)
                        .transition(.opacity)
                }

                layout
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 760, maxHeight: .infinity)
            }
            .developerMenu()
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.55), value: stage)
        .sensoryFeedback(trigger: stage) { old, new in
            Self.feedback(from: old, to: new)
        }
        .confirmationDialog("Cancel this focus?", isPresented: $confirmingCancel, titleVisibility: .visible) {
            Button("Cancel Focus", role: .destructive) { engine.cancel() }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("It won't be saved to your history.")
        }
    }

    // MARK: - Layout

    /// Stacked on a tall screen; side by side when the screen is short
    /// (a phone in landscape, or the closed iPhone Duo turned sideways).
    @ViewBuilder private var layout: some View {
        if verticalSizeClass == .compact {
            HStack(spacing: 40) {
                ClockArea(accent: accent)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 24) {
                    header
                    controls
                }
                .frame(maxWidth: 380)
            }
        } else {
            VStack(spacing: 24) {
                header
                Spacer(minLength: 8)
                ClockArea(accent: accent)
                Spacer(minLength: 8)
                controls
            }
        }
    }

    private var header: some View {
        FocusHeader(
            stage: stage,
            name: engine.session?.name ?? "",
            focusDuration: engine.session?.focusDuration ?? engine.focusDuration,
            breakDuration: engine.breakDuration,
            completionCount: engine.completionCount
        )
    }

    // MARK: - Controls

    private var controls: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 14) {
                switch stage {
                case .idle:
                    NameEntry(
                        engine: engine,
                        recentNames: recentNames,
                        isFocused: $nameFieldFocused,
                        nudge: nameNudge,
                        onSubmit: startFocus
                    )
                    PrimaryActionButton("Start Focus", systemImage: "play.fill", tint: Theme.tomato, action: startFocus)
                case .focusing:
                    PrimaryActionButton("Pause", systemImage: "pause.fill", tint: Theme.tomato) { engine.pause() }
                    SecondaryActionButton("Cancel", systemImage: "xmark") { confirmingCancel = true }
                case .paused:
                    PrimaryActionButton("Resume", systemImage: "play.fill", tint: Theme.tomato) { engine.resume() }
                    SecondaryActionButton("Cancel", systemImage: "xmark") { confirmingCancel = true }
                case .focusDone:
                    PrimaryActionButton(
                        "Take a \(DurationText.short(engine.breakDuration)) Break",
                        systemImage: "cup.and.saucer.fill",
                        tint: Theme.teal
                    ) { engine.startBreak() }
                    SecondaryActionButton("Done for Now", systemImage: "checkmark") { engine.finish() }
                case .onBreak:
                    PrimaryActionButton("End Break", systemImage: "forward.end.fill", tint: Theme.teal) { engine.endBreak() }
                case .breakDone:
                    PrimaryActionButton("Focus Again", systemImage: "arrow.clockwise", tint: Theme.tomato) { engine.focusAgain() }
                    SecondaryActionButton("Done", systemImage: "checkmark") { engine.finish() }
                }
            }
        }
        .frame(maxWidth: 520)
    }

    /// Start stays lit even before a name is typed; with no name it points
    /// at the field with a small shake instead of being a dead grey button.
    private func startFocus() {
        guard engine.canStart else {
            nameFieldFocused = true
            nameNudge += 1
            return
        }
        nameFieldFocused = false
        engine.startFocus()
    }

    /// Up to four recent session names, newest first, without repeats.
    private var recentNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for record in recentRecords where seen.insert(record.name.lowercased()).inserted {
            names.append(record.name)
            if names.count == 4 { break }
        }
        return names
    }

    // MARK: - Haptics

    /// Light, short taps for everyday actions. Finishing a focus gets its own
    /// richer pattern (see `CompletionHaptics`), so it's skipped here.
    private static func feedback(from old: FocusStage, to new: FocusStage) -> SensoryFeedback? {
        switch (old, new) {
        case (_, .focusDone):
            return nil
        case (.idle, .focusing), (.breakDone, .focusing), (.focusDone, .focusing):
            return .impact(weight: .medium, intensity: 0.8)
        case (.focusing, .paused):
            return .impact(weight: .light, intensity: 0.6)
        case (.paused, .focusing):
            return .impact(weight: .light, intensity: 0.8)
        case (.focusing, .idle), (.paused, .idle):
            return .impact(flexibility: .soft, intensity: 0.5)
        case (.focusDone, .onBreak):
            return .impact(flexibility: .soft, intensity: 0.7)
        case (.onBreak, .breakDone):
            return .impact(flexibility: .solid, intensity: 0.6)
        default:
            return .selection
        }
    }
}

// MARK: - Header

struct FocusHeader: View {
    let stage: FocusStage
    let name: String
    let focusDuration: TimeInterval
    let breakDuration: TimeInterval
    let completionCount: Int

    var body: some View {
        VStack(spacing: 10) {
            if stage == .focusDone {
                CompletionBadge(trigger: completionCount)
            }
            Text(eyebrow)
                .font(.retroLabel())
                .tracking(2.5)
                .foregroundStyle(Theme.accentText(for: stage))
            Text(title)
                .font(.retroDisplay(stage == .idle ? .largeTitle : .title))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .id(stage)
        .transition(.blurReplace)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var eyebrow: String {
        switch stage {
        case .idle:
            "\(DurationText.short(focusDuration)) focus · \(DurationText.short(breakDuration)) break".uppercased()
        case .focusing: "FOCUSING ON"
        case .paused: "PAUSED"
        case .focusDone: "SESSION COMPLETE"
        case .onBreak: "ON A BREAK"
        case .breakDone: "BREAK'S OVER"
        }
    }

    private var title: String {
        switch stage {
        case .idle: "Focus Time"
        case .focusing, .paused: name
        case .focusDone: "Nice work."
        case .onBreak: "Stretch. Sip. Breathe."
        case .breakDone: "Ready for another round?"
        }
    }

    private var subtitle: String? {
        switch stage {
        case .idle: nil
        case .focusing: nil
        case .paused: "Take your time. Resume when you're ready."
        case .focusDone: "\(DurationText.short(focusDuration)) on \(name)"
        case .onBreak: "Back to \(name) soon."
        case .breakDone: name
        }
    }
}

/// A seal that bounces in when a focus is completed.
struct CompletionBadge: View {
    let trigger: Int
    @State private var bounce = false

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(Theme.paper, Theme.mustard)
            .font(.system(size: 48, weight: .bold))
            .symbolEffect(.bounce, value: bounce)
            .task {
                try? await Task.sleep(for: .milliseconds(250))
                bounce.toggle()
            }
            .onChange(of: trigger) { bounce.toggle() }
            .accessibilityHidden(true)
    }
}

// MARK: - Name entry

struct NameEntry: View {
    @Bindable var engine: FocusEngine
    let recentNames: [String]
    var isFocused: FocusState<Bool>.Binding
    /// Goes up when Start is tapped without a name.
    var nudge: Int
    let onSubmit: () -> Void

    @State private var chipTaps = 0

    var body: some View {
        VStack(spacing: 12) {
            TextField("What are you focusing on?", text: $engine.draftName)
                .font(.title3.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.go)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .accessibilityLabel("Session name")
                .padding(.horizontal, 44)
                .padding(.vertical, 16)
                .overlay(alignment: .trailing) {
                    if !engine.draftName.isEmpty {
                        Button {
                            engine.draftName = ""
                            isFocused.wrappedValue = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.inkSoft.opacity(0.7))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear name")
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    }
                }
                .animation(.snappy(duration: 0.2), value: engine.draftName.isEmpty)
                .glassEffect(.regular.interactive(), in: .capsule)
                .modifier(Shake(progress: CGFloat(nudge)))
                .animation(.easeOut(duration: 0.45), value: nudge)
                .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: nudge)
                .onChange(of: engine.draftName) { _, newValue in
                    if newValue.count > FocusMachine.maxNameLength {
                        engine.draftName = String(newValue.prefix(FocusMachine.maxNameLength))
                    }
                }

            if !recentNames.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(recentNames, id: \.self) { name in
                            Button(name) {
                                engine.draftName = name
                                chipTaps += 1
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .accessibilityHint("Use this name")
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .sensoryFeedback(.selection, trigger: chipTaps)
            }
        }
    }
}

/// A quick side-to-side shake: three wiggles per step of `progress`.
struct Shake: GeometryEffect {
    var travel: CGFloat = 8
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(progress * .pi * 6), y: 0))
    }
}
