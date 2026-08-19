import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var showingEditDeck = false
    @State private var confirmingDeletion = false

    private var orderedCards: [Card] {
        deck.cards.sorted { $0.position < $1.position }
    }

    private var masteredCount: Int {
        deck.cards.count(where: \.mastered)
    }

    var body: some View {
        List {
            Section {
                if let description = deck.deckDescription, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                }

                ProgressView(
                    value: deck.cards.isEmpty ? 0 : Double(masteredCount) / Double(deck.cards.count)
                ) {
                    Text("Progression")
                } currentValueLabel: {
                    Text("\(masteredCount) / \(deck.cards.count)")
                }
            }

            Section("Cartes") {
                NavigationLink {
                    EditCardsView(deck: deck)
                } label: {
                    Label("Modifier les cartes", systemImage: "square.and.pencil")
                }

                if orderedCards.isEmpty {
                    Text("Ce deck ne contient encore aucune carte.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orderedCards.prefix(5)) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.term).font(.headline)
                            Text(card.definition)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    if orderedCards.count > 5 {
                        Text("Et \(orderedCards.count - 5) autre\(orderedCards.count - 5 > 1 ? "s" : "")…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Modifier le deck", systemImage: "pencil") { showingEditDeck = true }
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        confirmingDeletion = true
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showingEditDeck) {
            DeckFormView(deck: deck)
        }
        .alert("Supprimer ce deck ?", isPresented: $confirmingDeletion) {
            Button("Supprimer", role: .destructive) {
                modelContext.delete(deck)
                try? modelContext.save()
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes ses cartes seront supprimées définitivement.")
        }
    }
}
