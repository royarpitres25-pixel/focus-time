import SwiftUI
import UIKit

/// The retro palette: warm paper, espresso ink, and three 70s accents.
/// Every color has a light and a dark value.
enum Theme {
    static let paper = Color(light: 0xF3EAD7, dark: 0x1C1612)
    static let card = Color(light: 0xFBF6EC, dark: 0x2A221B)
    static let ink = Color(light: 0x2B1E16, dark: 0xF3EAD7)
    static let inkSoft = Color(light: 0x6E5A48, dark: 0xBBA992)

    /// Flip-clock tiles stay dark in both modes, like the real thing.
    static let tile = Color(light: 0x2B1E16, dark: 0x0E0B09)
    static let tileText = Color(light: 0xF8F1E2, dark: 0xF3EAD7)

    static let tomato = Color(light: 0xD2452A, dark: 0xEE6142)
    static let mustard = Color(light: 0xDF9B2F, dark: 0xF0B04A)
    static let teal = Color(light: 0x2A7D78, dark: 0x4FB1A7)

    // Darker versions for small text on paper, so it stays readable.
    static let tomatoText = Color(light: 0xB0351E, dark: 0xF07457)
    static let mustardText = Color(light: 0x85570C, dark: 0xF2BC62)
    static let tealText = Color(light: 0x1D6661, dark: 0x67C2B8)

    static let stripes: [Color] = [tomato, mustard, teal]

    /// Fill color for the stage: tomato for focus, mustard for a finished focus, teal for breaks.
    static func accent(for stage: FocusStage) -> Color {
        switch stage {
        case .idle, .focusing, .paused: tomato
        case .focusDone: mustard
        case .onBreak, .breakDone: teal
        }
    }

    /// Text-safe version of `accent(for:)`.
    static func accentText(for stage: FocusStage) -> Color {
        switch stage {
        case .idle, .focusing, .paused: tomatoText
        case .focusDone: mustardText
        case .onBreak, .breakDone: tealText
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// Heavy serif headlines: a 70s paperback cover feel. Scales with Dynamic Type.
    static func retroDisplay(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif, weight: .black)
    }

    /// Small typewriter-style labels, usually uppercase with wide tracking.
    static func retroLabel(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .monospaced, weight: .semibold)
    }

    /// Chunky rounded digits for the flip clock.
    static func clockDigits(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}
