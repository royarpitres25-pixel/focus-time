import SwiftUI

/// The one obvious action on each screen: a tinted, prominent Liquid Glass capsule.
struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    init(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.extraLarge)
        .tint(tint)
    }
}

/// A quieter, clear-glass action that sits under the primary one.
struct SecondaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}
