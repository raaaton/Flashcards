import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    ContentUnavailableView(
                        "Aucun deck",
                        systemImage: "rectangle.stack",
                        description: Text("Créez votre premier deck pour commencer à réviser.")
                    )
                } else {
                    List(decks) { deck in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(deck.name)
                                .font(.headline)
                            Text("\(deck.cards.count) carte\(deck.cards.count > 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Flashcards")
        }
    }
}
