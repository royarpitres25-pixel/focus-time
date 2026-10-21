import Foundation

/// Identifiers and storage locations shared by the app and the widget extension.
/// Everything stays on the device: there is no network code anywhere in the project.
enum AppGroup {
    static let identifier = "group.com.arpitroy.focustime"

    /// Shared defaults. Falls back to the standard defaults if the App Group
    /// isn't provisioned, so the app keeps working (the widget just won't see data).
    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    /// A folder both processes can read.
    static var containerURL: URL {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// The URL the widget and Live Activity open to bring up the Focus screen.
enum DeepLink {
    static let scheme = "focustime"
    static let focus = URL(string: "focustime://focus")!
}
