import Foundation

@main
enum BackupCodecSmoke {
    static func main() throws {
        let folderID = UUID()
        let deckID = UUID()
        let cardID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let localOnlyCard = BackupCardDTO(
            id: UUID(),
            term: "Local",
            definition: "Conservée",
            position: 1,
            mastered: false,
            timesStudied: 0,
            timesCorrect: 0
        )
        let originalCard = BackupCardDTO(
            id: cardID,
            term: "Terme",
            definition: "Définition",
            position: 0,
            mastered: true,
            timesStudied: 4,
            timesCorrect: 3
        )
        let envelope = BackupEnvelopeV1(
            exportedAt: date,
            scope: .database,
            folders: [BackupFolderDTO(id: folderID, name: "Dossier", createdAt: date)],
            decks: [
                BackupDeckDTO(
                    id: deckID,
                    name: "Deck",
                    deckDescription: "Description",
                    createdAt: date,
                    updatedAt: date,
                    folderID: folderID,
                    cards: [originalCard]
                )
            ]
        )

        let decoded = try BackupCodec.decode(BackupCodec.encode(envelope))
        precondition(decoded == envelope)

        var local = envelope
        local.decks[0].cards.append(localOnlyCard)
        var incoming = envelope
        incoming.decks[0].name = "Deck renommé"
        incoming.decks[0].cards[0].definition = "Définition mise à jour"
        let merged = BackupMerger.merge(local: local, incoming: incoming)
        precondition(merged.decks[0].name == "Deck renommé")
        precondition(merged.decks[0].cards.count == 2)
        precondition(merged.decks[0].cards.first { $0.id == cardID }?.definition == "Définition mise à jour")

        let unsupported = BackupEnvelopeV1(
            schemaVersion: 99,
            exportedAt: date,
            scope: .database,
            folders: envelope.folders,
            decks: envelope.decks
        )
        do {
            _ = try BackupCodec.decode(BackupCodec.encode(unsupported))
            preconditionFailure("An unsupported schema must fail")
        } catch BackupCodecError.unsupportedSchema(99) {
            // Expected.
        }

        print("Backup codec and merge smoke tests passed")
    }
}
