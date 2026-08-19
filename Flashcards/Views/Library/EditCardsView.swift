import SwiftData
import SwiftUI

struct EditCardsView: View {
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var showingNewCard = false
    @State private var showingBulkImport = false
    @State private var cardToEdit: Card?

    private var orderedCards: [Card] {
        deck.cards.sorted { $0.position < $1.position }
    }

    var body: some View {
        List {
            ForEach(orderedCards) { card in
                Button {
                    cardToEdit = card
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.term)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(card.definition)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Modifier cette carte")
            }
            .onDelete(perform: deleteCards)
            .onMove(perform: moveCards)
        }
        .overlay {
            if orderedCards.isEmpty {
                ContentUnavailableView(
                    "Aucune carte",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Ajoutez une carte avec le bouton +.")
                )
            }
        }
        .navigationTitle("Modifier les cartes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Ajouter une carte", systemImage: "plus") { showingNewCard = true }
                    Button("Importer en masse", systemImage: "text.badge.plus") { showingBulkImport = true }
                } label: {
                    Label("Ajouter", systemImage: "plus")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingNewCard) {
            CardFormView(deck: deck)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(deck: deck)
        }
        .sheet(item: $cardToEdit) { card in
            CardFormView(deck: deck, card: card)
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        let cards = orderedCards
        let removedIDs = Set(offsets.map { cards[$0].id })
        for offset in offsets {
            modelContext.delete(cards[offset])
        }
        for (position, card) in cards.filter({ !removedIDs.contains($0.id) }).enumerated() {
            card.position = position
        }
        deck.updatedAt = .now
        try? modelContext.save()
    }

    private func moveCards(from source: IndexSet, to destination: Int) {
        var cards = orderedCards
        cards.move(fromOffsets: source, toOffset: destination)
        for (position, card) in cards.enumerated() {
            card.position = position
        }
        deck.updatedAt = .now
        try? modelContext.save()
    }
}
