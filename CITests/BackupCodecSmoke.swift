import Foundation

@main
enum BackupCodecSmoke {
    static func main() throws {
        let folderID = UUID()
        let deckID = UUID()
        let cardID = UUID()
        let secondCardID = UUID()
        let localQuestionID = UUID()
        let sharedQuestionID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

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
        let configuration = DeckTestConfiguration(
            mode: .ai,
            multipleChoice: [
                AuthoredMultipleChoiceQuestion(
                    id: sharedQuestionID,
                    sourceCardID: cardID,
                    prompt: "Quelle définition ?",
                    choices: ["Définition", "Autre"],
                    correctChoiceIndex: 0
                )
            ],
            trueFalse: [
                AuthoredTrueFalseQuestion(
                    sourceCardID: cardID,
                    statement: "Le terme possède une définition.",
                    correctAnswer: true
                )
            ]
        )
        let envelope = BackupEnvelope(
            exportedAt: date,
            scope: .database,
            folders: [
                BackupFolderDTO(
                    id: folderID,
                    name: "Dossier",
                    createdAt: date,
                    iconName: "graduationcap.fill",
                    colorHex: "FF9500",
                    sortOrder: 3
                )
            ],
            decks: [
                BackupDeckDTO(
                    id: deckID,
                    name: "Deck",
                    createdAt: date,
                    updatedAt: date,
                    lastOpenedAt: date.addingTimeInterval(120),
                    completedStudySessions: 7,
                    activeStudySessionData: Data("resume".utf8),
                    studyHistoryData: Data("history".utf8),
                    lastStudyActivityAt: date.addingTimeInterval(180),
                    isPinned: true,
                    folderID: folderID,
                    cards: [originalCard],
                    testConfiguration: configuration
                )
            ]
        )

        let encoded = try BackupCodec.encode(envelope)
        let rawV2 = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        precondition(rawV2["schemaVersion"] as? Int == 2)
        let rawDeck = (rawV2["decks"] as! [[String: Any]])[0]
        precondition(rawDeck["testConfiguration"] is [String: Any])

        let decoded = try BackupCodec.decode(encoded)
        precondition(decoded.schemaVersion == 2)
        precondition(decoded.decks[0].testConfiguration == configuration)
        precondition(decoded.decks[0].cards[0].isStarred)

        var v1JSON = rawV2
        v1JSON["schemaVersion"] = 1
        var v1Decks = v1JSON["decks"] as! [[String: Any]]
        v1Decks[0].removeValue(forKey: "testConfiguration")
        v1JSON["decks"] = v1Decks
        let v1Data = try JSONSerialization.data(withJSONObject: v1JSON)
        let decodedV1 = try BackupCodec.decode(v1Data)
        precondition(decodedV1.decks[0].testConfiguration == .useFlashcards)

        let localOnlyCard = BackupCardDTO(
            id: secondCardID,
            term: "Local",
            definition: "Conservée",
            position: 1,
            mastered: false,
            timesStudied: 0,
            timesCorrect: 0
        )
        let localOnlyQuestion = AuthoredTrueFalseQuestion(
            id: localQuestionID,
            sourceCardID: secondCardID,
            statement: "Question locale",
            correctAnswer: true
        )
        var local = envelope
        local.decks[0].cards.append(localOnlyCard)
        local.decks[0].testConfiguration.trueFalse.append(localOnlyQuestion)

        var incoming = envelope
        incoming.decks[0].name = "Deck renommé"
        incoming.decks[0].lastOpenedAt = nil
        incoming.decks[0].cards[0].definition = "Définition mise à jour"
        incoming.decks[0].testConfiguration.multipleChoice[0].prompt = "Question mise à jour"
        let merged = try BackupMerger.merge(local: local, incoming: incoming)
        precondition(merged.decks[0].name == "Deck renommé")
        precondition(merged.decks[0].cards.count == 2)
        precondition(merged.decks[0].lastOpenedAt == date.addingTimeInterval(120))
        precondition(merged.decks[0].testConfiguration.multipleChoice[0].prompt == "Question mise à jour")
        precondition(merged.decks[0].testConfiguration.trueFalse.contains { $0.id == localQuestionID })

        var legacyIncoming = decodedV1
        legacyIncoming.decks[0].cards = [originalCard]
        let cleared = try BackupMerger.merge(local: local, incoming: legacyIncoming)
        precondition(cleared.decks[0].testConfiguration == .useFlashcards)

        var orphaned = envelope
        orphaned.decks[0].testConfiguration.multipleChoice[0].sourceCardID = UUID()
        do {
            _ = try BackupMerger.merge(local: envelope, incoming: orphaned)
            preconditionFailure("An orphaned source reference must fail after merge")
        } catch BackupCodecError.invalidTestConfiguration {
            // Expected.
        }

        var invalidIndex = envelope
        invalidIndex.decks[0].testConfiguration.multipleChoice[0].correctChoiceIndex = 9
        do {
            _ = try BackupCodec.decode(BackupCodec.encode(invalidIndex))
            preconditionFailure("An invalid answer index must fail")
        } catch BackupCodecError.invalidTestConfiguration {
            // Expected.
        }

        var futureJSON = rawV2
        futureJSON["schemaVersion"] = 99
        let futureData = try JSONSerialization.data(withJSONObject: futureJSON)
        do {
            _ = try BackupCodec.decode(futureData)
            preconditionFailure("An unsupported schema must fail")
        } catch BackupCodecError.unsupportedSchema(99) {
            // Expected.
        }

        print("Backup v1/v2 codec and merge smoke tests passed")
    }
}
