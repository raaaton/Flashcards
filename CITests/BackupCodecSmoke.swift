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
            timesCorrect: 3,
            isStarred: true
        )
        let envelope = BackupEnvelopeV1(
            exportedAt: date,
            scope: .database,
            folders: [
                BackupFolderDTO(
                    id: folderID,
                    name: "Dossier",
                    createdAt: date,
                    iconName: "graduationcap.fill",
                    colorHex: "FF9500"
                )
            ],
            decks: [
                BackupDeckDTO(
                    id: deckID,
                    name: "Deck",
                    deckDescription: "Description",
                    createdAt: date,
                    updatedAt: date,
                    lastOpenedAt: date.addingTimeInterval(120),
                    completedStudySessions: 7,
                    activeStudySessionData: Data("resume".utf8),
                    studyHistoryData: Data("history".utf8),
                    lastStudyActivityAt: date.addingTimeInterval(180),
                    isPinned: true,
                    folderID: folderID,
                    cards: [originalCard]
                )
            ]
        )

        let decoded = try BackupCodec.decode(BackupCodec.encode(envelope))
        precondition(decoded == envelope)
        precondition(decoded.folders[0].iconName == "graduationcap.fill")
        precondition(decoded.folders[0].colorHex == "FF9500")
        precondition(decoded.decks[0].completedStudySessions == 7)
        precondition(decoded.decks[0].activeStudySessionData == Data("resume".utf8))
        precondition(decoded.decks[0].lastOpenedAt == date.addingTimeInterval(120))
        precondition(decoded.decks[0].lastStudyActivityAt == date.addingTimeInterval(180))
        precondition(decoded.decks[0].isPinned)
        precondition(decoded.decks[0].cards[0].isStarred)

        var legacyJSON = try JSONSerialization.jsonObject(
            with: BackupCodec.encode(envelope)
        ) as! [String: Any]
        var legacyFolders = legacyJSON["folders"] as! [[String: Any]]
        legacyFolders[0].removeValue(forKey: "iconName")
        legacyFolders[0].removeValue(forKey: "colorHex")
        legacyJSON["folders"] = legacyFolders
        var legacyDecks = legacyJSON["decks"] as! [[String: Any]]
        legacyDecks[0].removeValue(forKey: "completedStudySessions")
        legacyDecks[0].removeValue(forKey: "activeStudySessionData")
        legacyDecks[0].removeValue(forKey: "lastOpenedAt")
        legacyDecks[0].removeValue(forKey: "studyHistoryData")
        legacyDecks[0].removeValue(forKey: "lastStudyActivityAt")
        legacyDecks[0].removeValue(forKey: "isPinned")
        var legacyCards = legacyDecks[0]["cards"] as! [[String: Any]]
        legacyCards[0].removeValue(forKey: "isStarred")
        legacyDecks[0]["cards"] = legacyCards
        legacyJSON["decks"] = legacyDecks
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSON)
        let decodedLegacy = try BackupCodec.decode(legacyData)
        precondition(decodedLegacy.folders[0].iconName == "folder.fill")
        precondition(decodedLegacy.folders[0].colorHex == "5856D6")
        precondition(decodedLegacy.decks[0].completedStudySessions == 0)
        precondition(decodedLegacy.decks[0].activeStudySessionData == nil)
        precondition(decodedLegacy.decks[0].lastOpenedAt == nil)
        precondition(decodedLegacy.decks[0].lastStudyActivityAt == nil)
        precondition(!decodedLegacy.decks[0].isPinned)
        precondition(!decodedLegacy.decks[0].cards[0].isStarred)

        var local = envelope
        local.decks[0].cards.append(localOnlyCard)
        var incoming = envelope
        incoming.decks[0].name = "Deck renommé"
        incoming.decks[0].lastOpenedAt = nil
        incoming.decks[0].cards[0].definition = "Définition mise à jour"
        let merged = BackupMerger.merge(local: local, incoming: incoming)
        precondition(merged.decks[0].name == "Deck renommé")
        precondition(merged.decks[0].cards.count == 2)
        precondition(merged.decks[0].lastOpenedAt == date.addingTimeInterval(120))
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
