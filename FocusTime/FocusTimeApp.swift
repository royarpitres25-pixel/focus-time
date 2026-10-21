import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct FocusTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var engine: FocusEngine

    init() {
        let container = SharedStore.makeContainer()
        self.container = container
        _engine = State(initialValue: FocusEngine(context: container.mainContext))
        Self.styleNavigationTitles()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
        }
        .modelContainer(container)
    }

    /// Heavy serif navigation titles to match the retro type.
    private static func styleNavigationTitles() {
        let appearance = UINavigationBar.appearance()
        if let large = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif) {
            let black = large.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.black]])
            appearance.largeTitleTextAttributes = [.font: UIFont(descriptor: black, size: 0)]
        }
        if let inline = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.serif) {
            let heavy = inline.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.heavy]])
            appearance.titleTextAttributes = [.font: UIFont(descriptor: heavy, size: 0)]
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// The app already shows the finish on screen, so skip the banner while it's open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
