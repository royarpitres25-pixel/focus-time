import SwiftUI

/// Three parallel 70s racing stripes: tomato, mustard, teal.
/// The signature mark shared by the app, the widget, and the Live Activity.
struct RetroStripes: View {
    var axis: Axis = .horizontal
    var thickness: CGFloat = 5
    var spacing: CGFloat = 3

    var body: some View {
        Group {
            if axis == .horizontal {
                VStack(spacing: spacing) { bars }
            } else {
                HStack(spacing: spacing) { bars }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var bars: some View {
        ForEach(Theme.stripes.indices, id: \.self) { index in
            Capsule(style: .continuous)
                .fill(Theme.stripes[index])
                .frame(
                    width: axis == .vertical ? thickness : nil,
                    height: axis == .horizontal ? thickness : nil
                )
        }
    }
}

/// One dot per completed focus session today.
struct SessionDots: View {
    var count: Int
    var accent: Color = Theme.tomato
    var limit = 8
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: size * 0.6) {
            if count == 0 {
                Text("No sessions yet")
                    .font(.retroLabel(.caption2))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                ForEach(0..<min(count, limit), id: \.self) { _ in
                    Circle()
                        .fill(accent)
                        .frame(width: size, height: size)
                }
                if count > limit {
                    Text("+\(count - limit)")
                        .font(.retroLabel(.caption2))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "1 session" : "\(count) sessions")
    }
}

/// A dark flip-clock tile with a hinge line across the middle.
struct FlipTileBackground: View {
    var cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.tile)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.10), .clear, .black.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Rectangle()
                .fill(.black.opacity(0.45))
                .frame(height: max(1, cornerRadius * 0.12))
        }
    }
}
