import SwiftData

@MainActor
enum LibraryActions {
    @discardableResult
    static func duplicateDeck(_ source: Deck, in modelContext: ModelContext) -> Deck {
        let copy = Deck(name: "\(source.name) — copie", folder: source.folder)
        copy.deckDescription = source.deckDescription
        modelContext.insert(copy)

        for sourceCard in source.cards.sorted(by: { $0.position < $1.position }) {
            let card = Card(
                term: sourceCard.term,
                definition: sourceCard.definition,
                position: sourceCard.position
            )
            card.isStarred = sourceCard.isStarred
            card.deck = copy
            modelContext.insert(card)
        }

        try? modelContext.save()
        return copy
    }

    @discardableResult
    static func duplicateFolder(_ source: Folder, in modelContext: ModelContext) -> Folder {
        let copy = Folder(
            name: "\(source.name) — copie",
            iconName: source.iconName,
            colorHex: source.colorHex
        )
        modelContext.insert(copy)

        for sourceDeck in source.decks.sorted(by: { $0.createdAt < $1.createdAt }) {
            let deck = Deck(name: sourceDeck.name, folder: copy)
            deck.deckDescription = sourceDeck.deckDescription
            modelContext.insert(deck)

            for sourceCard in sourceDeck.cards.sorted(by: { $0.position < $1.position }) {
                let card = Card(
                    term: sourceCard.term,
                    definition: sourceCard.definition,
                    position: sourceCard.position
                )
                card.isStarred = sourceCard.isStarred
                card.deck = deck
                modelContext.insert(card)
            }
        }

        try? modelContext.save()
        return copy
    }

    static func deleteFolderKeepingDecks(_ folder: Folder, in modelContext: ModelContext) {
        for deck in Array(folder.decks) {
            deck.folder = nil
            deck.updatedAt = .now
        }
        modelContext.delete(folder)
        try? modelContext.save()
    }

    static func resetStudyProgress(for deck: Deck, in modelContext: ModelContext) {
        for card in deck.cards {
            card.mastered = false
        }
        deck.completedStudySessions = 0
        deck.activeStudySessionData = nil
        deck.updatedAt = .now
        try? modelContext.save()
    }
}
