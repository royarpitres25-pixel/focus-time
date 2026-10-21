import SwiftUI

#if DEBUG
/// Debug builds only: switch to 15-second focus and 10-second break timers
/// to try the whole flow quickly. Release builds don't include this menu.
private struct DeveloperMenu: View {
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        Menu {
            Toggle(isOn: Binding(
                get: { engine.useTestDurations },
                set: { engine.setTestDurations($0) }
            )) {
                Label("Short Test Timers", systemImage: "hare")
            }
            Text("Applies to the next session")
        } label: {
            Image(systemName: "hammer")
        }
        .accessibilityLabel("Developer options")
    }
}

extension View {
    func developerMenu() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DeveloperMenu()
            }
        }
    }
}
#else
extension View {
    func developerMenu() -> some View { self }
}
#endif
