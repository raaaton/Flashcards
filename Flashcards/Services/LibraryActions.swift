import Foundation
import SwiftData

@MainActor
enum LibraryActions {
    @discardableResult
    static func duplicateDeck(_ source: Deck, in modelContext: ModelContext) -> Deck {
        let copy = Deck(name: "\(source.name) — copie", folder: source.folder)
        modelContext.insert(copy)
        var cardIDMap: [UUID: UUID] = [:]

        for sourceCard in source.cards.sorted(by: { $0.position < $1.position }) {
            let card = Card(
                term: sourceCard.term,
                definition: sourceCard.definition,
                position: sourceCard.position
            )
            card.isStarred = sourceCard.isStarred
            card.deck = copy
            modelContext.insert(card)
            cardIDMap[sourceCard.id] = card.id
        }

        copy.setTestConfiguration(
            source.testConfiguration.duplicated(remappingCardIDs: cardIDMap)
        )

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
            modelContext.insert(deck)
            var cardIDMap: [UUID: UUID] = [:]

            for sourceCard in sourceDeck.cards.sorted(by: { $0.position < $1.position }) {
                let card = Card(
                    term: sourceCard.term,
                    definition: sourceCard.definition,
                    position: sourceCard.position
                )
                card.isStarred = sourceCard.isStarred
                card.deck = deck
                modelContext.insert(card)
                cardIDMap[sourceCard.id] = card.id
            }

            deck.setTestConfiguration(
                sourceDeck.testConfiguration.duplicated(remappingCardIDs: cardIDMap)
            )
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

    static func resetTestProgress(for deck: Deck, in modelContext: ModelContext) {
        for card in deck.cards {
            card.testMastered = false
        }
        deck.completedTestSessions = 0
        deck.activeTestSessionData = nil
        deck.updatedAt = .now
        try? modelContext.save()
    }

    static func moveCards(
        _ cards: [Card],
        from source: Deck,
        to destination: Deck,
        in modelContext: ModelContext
    ) {
        guard source.id != destination.id, !cards.isEmpty else { return }
        let movedIDs = Set(cards.map(\.id))
        let destinationStart = (destination.cards.map(\.position).max() ?? -1) + 1
        let sourceConfiguration = source.testConfiguration
        let linkedQuestions = sourceConfiguration.questionsLinked(to: movedIDs)

        for (offset, card) in cards.sorted(by: { $0.position < $1.position }).enumerated() {
            card.position = destinationStart + offset
            card.deck = destination
        }
        normalizePositions(source.cards.filter { !movedIDs.contains($0.id) })
        normalizePositions(destination.cards.filter { !movedIDs.contains($0.id) } + cards)

        if linkedQuestions.authoredQuestionCount > 0 {
            source.setTestConfiguration(
                sourceConfiguration.removingQuestions(linkedTo: movedIDs)
            )
            let destinationConfiguration = destination.testConfiguration
            let destinationMode = destinationConfiguration.mode == .useFlashcards
                ? sourceConfiguration.mode
                : destinationConfiguration.mode
            destination.setTestConfiguration(
                destinationConfiguration.mergingQuestions(
                    from: DeckTestConfiguration(
                        mode: destinationMode,
                        multipleChoice: linkedQuestions.multipleChoice,
                        trueFalse: linkedQuestions.trueFalse
                    )
                )
            )
        }
        source.updatedAt = .now
        destination.updatedAt = .now
        saveOrRollback(modelContext)
    }

    static func copyCards(
        _ cards: [Card],
        to destination: Deck,
        in modelContext: ModelContext
    ) {
        guard !cards.isEmpty else { return }
        let destinationStart = (destination.cards.map(\.position).max() ?? -1) + 1

        for (offset, sourceCard) in cards.sorted(by: { $0.position < $1.position }).enumerated() {
            let copy = Card(
                term: sourceCard.term,
                definition: sourceCard.definition,
                position: destinationStart + offset
            )
            copy.isStarred = sourceCard.isStarred
            copy.deck = destination
            modelContext.insert(copy)
        }
        destination.updatedAt = .now
        try? modelContext.save()
    }

    static func deleteCards(
        _ cards: [Card],
        from deck: Deck,
        in modelContext: ModelContext
    ) {
        guard !cards.isEmpty else { return }
        let deletedIDs = Set(cards.map(\.id))
        deck.setTestConfiguration(
            deck.testConfiguration.removingQuestions(linkedTo: deletedIDs)
        )
        for card in cards {
            modelContext.delete(card)
        }
        normalizePositions(deck.cards.filter { !deletedIDs.contains($0.id) })
        deck.updatedAt = .now
        saveOrRollback(modelContext)
    }

    static func setStarred(
        _ isStarred: Bool,
        for cards: [Card],
        in deck: Deck,
        modelContext: ModelContext
    ) {
        guard !cards.isEmpty else { return }
        for card in cards {
            card.isStarred = isStarred
        }
        deck.updatedAt = .now
        try? modelContext.save()
    }

    static func linkedQuestionCount(for cards: [Card], in deck: Deck) -> Int {
        let cardIDs = Set(cards.map(\.id))
        return deck.testConfiguration.questionsLinked(to: cardIDs).authoredQuestionCount
    }

    private static func normalizePositions(_ cards: [Card]) {
        for (position, card) in cards.sorted(by: { $0.position < $1.position }).enumerated() {
            card.position = position
        }
    }

    private static func saveOrRollback(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}
