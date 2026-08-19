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
        "Dossiers : \(addedFolders) ajoutés, \(updatedFolders) mis à jour. "
            + "Decks : \(addedDecks) ajoutés, \(updatedDecks) mis à jour. "
            + "Cartes : \(addedCards) ajoutées, \(updatedCards) mises à jour."
    }
}

@MainActor
enum BackupService {
    static func databaseEnvelope(folders: [Folder], decks: [Deck]) -> BackupEnvelopeV1 {
        BackupEnvelopeV1(
            scope: .database,
            folders: folders.map(folderDTO),
            decks: decks.map(deckDTO)
        )
    }

    static func deckEnvelope(_ deck: Deck) -> BackupEnvelopeV1 {
        BackupEnvelopeV1(
            scope: .deck,
            folders: deck.folder.map { [folderDTO($0)] } ?? [],
            decks: [deckDTO(deck)]
        )
    }

    static func temporaryJSONFile(
        for envelope: BackupEnvelopeV1,
        suggestedName: String
    ) throws -> URL {
        let safeName = suggestedName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = (safeName.isEmpty ? "Flashcards" : safeName) + ".json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try BackupCodec.encode(envelope).write(to: url, options: .atomic)
        return url
    }

    static func importEnvelope(
        _ envelope: BackupEnvelopeV1,
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
                    report.updatedFolders += 1
                } else {
                    let folder = Folder(name: dto.name)
                    folder.id = dto.id
                    folder.createdAt = dto.createdAt
                    modelContext.insert(folder)
                    foldersByID[dto.id] = folder
                    report.addedFolders += 1
                }
            }

            for dto in envelope.decks {
                let deck: Deck
                if let existingDeck = decksByID[dto.id] {
                    deck = existingDeck
                    report.updatedDecks += 1
                } else {
                    deck = Deck(name: dto.name)
                    deck.id = dto.id
                    modelContext.insert(deck)
                    decksByID[dto.id] = deck
                    report.addedDecks += 1
                }

                deck.name = dto.name
                deck.deckDescription = dto.deckDescription
                deck.createdAt = dto.createdAt
                deck.updatedAt = dto.updatedAt
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
                    card.deck = deck
                }
            }

            try modelContext.save()
            return report
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private static func folderDTO(_ folder: Folder) -> BackupFolderDTO {
        BackupFolderDTO(id: folder.id, name: folder.name, createdAt: folder.createdAt)
    }

    private static func deckDTO(_ deck: Deck) -> BackupDeckDTO {
        BackupDeckDTO(
            id: deck.id,
            name: deck.name,
            deckDescription: deck.deckDescription,
            createdAt: deck.createdAt,
            updatedAt: deck.updatedAt,
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
                        timesCorrect: $0.timesCorrect
                    )
                }
        )
    }
}
