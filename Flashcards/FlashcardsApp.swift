import SwiftData
import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var settings = AppSettings()

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            Folder.self,
            Deck.self,
            Card.self
        ])
        let configuration = ModelConfiguration(
            "Local",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible de créer la base locale : \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(settings)
                .environment(\.locale, settings.locale ?? Locale.autoupdatingCurrent)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
