import SwiftUI

struct RootView: View {
    enum AppTab: Hashable {
        case focus
        case history
    }

    @Environment(FocusEngine.self) private var engine
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .focus

    var body: some View {
        TabView(selection: $selection) {
            Tab("Focus", systemImage: "timer", value: AppTab.focus) {
                FocusScreen()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryScreen()
            }
        }
        // Tabs on the outer screen; a sidebar when there's room, like the open iPhone Duo.
        .tabViewStyle(.sidebarAdaptable)
        .tint(Theme.tomato)
        .onOpenURL { url in
            guard url.scheme == DeepLink.scheme else { return }
            selection = .focus
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                engine.sceneDidBecomeActive()
            }
        }
    }
}
