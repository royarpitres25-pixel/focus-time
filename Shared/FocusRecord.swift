import Foundation
import SwiftData

/// A completed focus session, saved on the device with SwiftData.
@Model
final class FocusRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var startedAt: Date
    var completedAt: Date
    /// Focused seconds. Breaks are never included.
    var duration: TimeInterval

    init(id: UUID, name: String, startedAt: Date, completedAt: Date, duration: TimeInterval) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
    }

    var summary: FocusSummary {
        FocusSummary(id: id, completedAt: completedAt, duration: duration)
    }
}

/// Opens the on-device store in the App Group so the widget reads the same history.
enum SharedStore {
    static var storeURL: URL {
        AppGroup.containerURL.appending(path: "FocusTime.store")
    }

    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: FocusRecord.self, configurations: configuration)
        } catch {
            // Keep the app usable even if the store can't be opened.
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: FocusRecord.self, configurations: memory)
        }
    }

    /// Focus sessions completed on or after `start`.
    static func summaries(since start: Date) -> [FocusSummary] {
        guard let container = try? ModelContainer(
            for: FocusRecord.self,
            configurations: ModelConfiguration(url: storeURL, allowsSave: false, cloudKitDatabase: .none)
        ) else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FocusRecord>(predicate: #Predicate { $0.completedAt >= start })
        return ((try? context.fetch(descriptor)) ?? []).map(\.summary)
    }
}
