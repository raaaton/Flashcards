import Foundation
import SwiftData

struct BackupImportReport: Sendable {
    var addedFolders = 0
    var updatedFolders = 0
    var addedDecks = 0
    var updatedDecks = 0
    var addedCards = 0
    var updatedCards = 0

    var summary: String {
        L10n.format(
            "backup.import.summary",
            Int64(addedFolders),
            Int64(updatedFolders),
            Int64(addedDecks),
            Int64(updatedDecks),
            Int64(addedCards),
            Int64(updatedCards)
        )
    }
}

@MainActor
enum BackupService {
    static func databaseEnvelope(folders: [Folder], decks: [Deck]) -> BackupEnvelope {
        BackupEnvelope(
            scope: .database,
            folders: folders
                .sorted {
                    if $0.sortOrder == $1.sortOrder {
                        return $0.createdAt < $1.createdAt
                    }
                    return $0.sortOrder < $1.sortOrder
                }
                .map(folderDTO),
            decks: decks.map(deckDTO)
        )
    }

    static func deckEnvelope(_ deck: Deck) -> BackupEnvelope {
        BackupEnvelope(
            scope: .deck,
            folders: deck.folder.map { [folderDTO($0)] } ?? [],
            decks: [deckDTO(deck)]
        )
    }

    static func temporaryJSONFile(
        for envelope: BackupEnvelope,
        suggestedName: String
    ) throws -> URL {
        let safeName = suggestedName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = (safeName.isEmpty ? "Kavi" : safeName) + ".json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try BackupCodec.encode(envelope).write(to: url, options: .atomic)
        return url
    }

    static func importEnvelope(
        _ envelope: BackupEnvelope,
        into modelContext: ModelContext
    ) throws -> BackupImportReport {
        var report = BackupImportReport()

        do {
            let existingFolders = try modelContext.fetch(FetchDescriptor<Folder>())
            let existingDecks = try modelContext.fetch(FetchDescriptor<Deck>())
            let existingCards = try modelContext.fetch(FetchDescriptor<Card>())
            var foldersByID = Dictionary(uniqueKeysWithValues: existingFolders.map { ($0.id, $0) })
            var decksByID = Dictionary(uniqueKeysWithValues: existingDecks.map { ($0.id, $0) })
            var cardsByID = Dictionary(uniqueKeysWithValues: existingCards.map { ($0.id, $0) })

            for dto in envelope.folders {
                if let folder = foldersByID[dto.id] {
                    folder.name = dto.name
                    folder.createdAt = dto.createdAt
                    folder.iconName = dto.iconName
                    folder.colorHex = dto.colorHex
                    folder.sortOrder = dto.sortOrder
                    report.updatedFolders += 1
                } else {
                    let folder = Folder(
                        name: dto.name,
                        iconName: dto.iconName,
                        colorHex: dto.colorHex,
                        sortOrder: dto.sortOrder
                    )
                    folder.id = dto.id
                    folder.createdAt = dto.createdAt
                    modelContext.insert(folder)
                    foldersByID[dto.id] = folder
                    report.addedFolders += 1
                }
            }

            for dto in envelope.decks {
                let deck: Deck
                let existingConfiguration: DeckTestConfiguration
                if let existingDeck = decksByID[dto.id] {
                    deck = existingDeck
                    existingConfiguration = existingDeck.testConfiguration
                    report.updatedDecks += 1
                } else {
                    deck = Deck(name: dto.name)
                    deck.id = dto.id
                    modelContext.insert(deck)
                    decksByID[dto.id] = deck
                    existingConfiguration = .useFlashcards
                    report.addedDecks += 1
                }

                deck.name = dto.name
                deck.createdAt = dto.createdAt
                deck.updatedAt = dto.updatedAt
                deck.lastOpenedAt = dto.lastOpenedAt ?? deck.lastOpenedAt
                deck.completedStudySessions = dto.completedStudySessions
                deck.activeStudySessionData = dto.activeStudySessionData
                deck.studyHistoryData = dto.studyHistoryData
                deck.lastStudyActivityAt = dto.lastStudyActivityAt
                deck.isPinned = dto.isPinned
                deck.folder = dto.folderID.flatMap { foldersByID[$0] }

                for cardDTO in dto.cards {
                    let card: Card
                    if let existingCard = cardsByID[cardDTO.id] {
                        card = existingCard
                        report.updatedCards += 1
                    } else {
                        card = Card(
                            term: cardDTO.term,
                            definition: cardDTO.definition,
                            position: cardDTO.position
                        )
                        card.id = cardDTO.id
                        modelContext.insert(card)
                        cardsByID[cardDTO.id] = card
                        report.addedCards += 1
                    }

                    card.term = cardDTO.term
                    card.definition = cardDTO.definition
                    card.position = cardDTO.position
                    card.mastered = cardDTO.mastered
                    card.timesStudied = cardDTO.timesStudied
                    card.timesCorrect = cardDTO.timesCorrect
                    card.isStarred = cardDTO.isStarred
                    card.deck = deck
                }

                let mergedConfiguration = existingConfiguration.mergingQuestions(
                    from: dto.testConfiguration
                )
                let validCardIDs = Set(
                    cardsByID.values.lazy
                        .filter { $0.deck?.id == deck.id }
                        .map(\.id)
                )
                deck.setTestConfiguration(
                    try mergedConfiguration.validated(validCardIDs: validCardIDs)
                )
            }

            try modelContext.save()
            return report
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private static func folderDTO(_ folder: Folder) -> BackupFolderDTO {
        BackupFolderDTO(
            id: folder.id,
            name: folder.name,
            createdAt: folder.createdAt,
            iconName: folder.iconName,
            colorHex: folder.colorHex,
            sortOrder: folder.sortOrder
        )
    }

    private static func deckDTO(_ deck: Deck) -> BackupDeckDTO {
        BackupDeckDTO(
            id: deck.id,
            name: deck.name,
            createdAt: deck.createdAt,
            updatedAt: deck.updatedAt,
            lastOpenedAt: deck.lastOpenedAt,
            completedStudySessions: deck.completedStudySessions,
            activeStudySessionData: deck.activeStudySessionData,
            studyHistoryData: deck.studyHistoryData,
            lastStudyActivityAt: deck.lastStudyActivityAt,
            isPinned: deck.isPinned,
            folderID: deck.folder?.id,
            cards: deck.cards
                .sorted { $0.position < $1.position }
                .map {
                    BackupCardDTO(
                        id: $0.id,
                        term: $0.term,
                        definition: $0.definition,
                        position: $0.position,
                        mastered: $0.mastered,
                        timesStudied: $0.timesStudied,
                        timesCorrect: $0.timesCorrect,
                        isStarred: $0.isStarred
                    )
                },
            testConfiguration: deck.testConfiguration
        )
    }
}
