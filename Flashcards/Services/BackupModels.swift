import Foundation

enum BackupScope: String, Codable, Sendable {
    case deck
    case database
}

struct BackupFolderDTO: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
    var iconName: String
    var colorHex: String
    var sortOrder: Int

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        iconName: String = "folder.fill",
        colorHex: String = "5856D6",
        sortOrder: Int = Int.max
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, iconName, colorHex, sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "folder.fill"
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "5856D6"
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? Int.max
    }
}

struct BackupCardDTO: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var term: String
    var definition: String
    var position: Int
    var mastered: Bool
    var testMastered: Bool
    var timesStudied: Int
    var timesCorrect: Int
    var isStarred: Bool

    init(
        id: UUID,
        term: String,
        definition: String,
        position: Int,
        mastered: Bool,
        testMastered: Bool = false,
        timesStudied: Int,
        timesCorrect: Int,
        isStarred: Bool = false
    ) {
        self.id = id
        self.term = term
        self.definition = definition
        self.position = position
        self.mastered = mastered
        self.testMastered = testMastered
        self.timesStudied = timesStudied
        self.timesCorrect = timesCorrect
        self.isStarred = isStarred
    }

    private enum CodingKeys: String, CodingKey {
        case id, term, definition, position, mastered, testMastered
        case timesStudied, timesCorrect, isStarred
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        term = try container.decode(String.self, forKey: .term)
        definition = try container.decode(String.self, forKey: .definition)
        position = try container.decode(Int.self, forKey: .position)
        mastered = try container.decode(Bool.self, forKey: .mastered)
        testMastered = try container.decodeIfPresent(Bool.self, forKey: .testMastered) ?? false
        timesStudied = try container.decode(Int.self, forKey: .timesStudied)
        timesCorrect = try container.decode(Int.self, forKey: .timesCorrect)
        isStarred = try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
    }
}

struct BackupDeckDTO: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?
    var completedStudySessions: Int
    var activeStudySessionData: Data?
    var completedTestSessions: Int
    var activeTestSessionData: Data?
    var studyHistoryData: Data?
    var lastStudyActivityAt: Date?
    var lastTestActivityAt: Date?
    var isPinned: Bool
    var folderID: UUID?
    var cards: [BackupCardDTO]
    var testConfiguration: DeckTestConfiguration

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        lastOpenedAt: Date? = nil,
        completedStudySessions: Int = 0,
        activeStudySessionData: Data? = nil,
        completedTestSessions: Int = 0,
        activeTestSessionData: Data? = nil,
        studyHistoryData: Data? = nil,
        lastStudyActivityAt: Date? = nil,
        lastTestActivityAt: Date? = nil,
        isPinned: Bool = false,
        folderID: UUID?,
        cards: [BackupCardDTO],
        testConfiguration: DeckTestConfiguration = .useFlashcards
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.completedStudySessions = completedStudySessions
        self.activeStudySessionData = activeStudySessionData
        self.completedTestSessions = completedTestSessions
        self.activeTestSessionData = activeTestSessionData
        self.studyHistoryData = studyHistoryData
        self.lastStudyActivityAt = lastStudyActivityAt
        self.lastTestActivityAt = lastTestActivityAt
        self.isPinned = isPinned
        self.folderID = folderID
        self.cards = cards
        self.testConfiguration = testConfiguration
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, updatedAt, lastOpenedAt
        case completedStudySessions, activeStudySessionData, studyHistoryData
        case completedTestSessions, activeTestSessionData, lastTestActivityAt
        case lastStudyActivityAt, isPinned, folderID, cards, testConfiguration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        completedStudySessions = try container.decodeIfPresent(
            Int.self,
            forKey: .completedStudySessions
        ) ?? 0
        activeStudySessionData = try container.decodeIfPresent(
            Data.self,
            forKey: .activeStudySessionData
        )
        completedTestSessions = try container.decodeIfPresent(
            Int.self,
            forKey: .completedTestSessions
        ) ?? 0
        activeTestSessionData = try container.decodeIfPresent(
            Data.self,
            forKey: .activeTestSessionData
        )
        studyHistoryData = try container.decodeIfPresent(Data.self, forKey: .studyHistoryData)
        lastStudyActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastStudyActivityAt)
        lastTestActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastTestActivityAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        cards = try container.decode([BackupCardDTO].self, forKey: .cards)
        testConfiguration = try container.decode(
            DeckTestConfiguration.self,
            forKey: .testConfiguration
        )
    }
}

private struct LegacyBackupDeckDTO: Decodable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?
    var completedStudySessions: Int
    var activeStudySessionData: Data?
    var studyHistoryData: Data?
    var lastStudyActivityAt: Date?
    var isPinned: Bool
    var folderID: UUID?
    var cards: [BackupCardDTO]

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, updatedAt, lastOpenedAt
        case completedStudySessions, activeStudySessionData, studyHistoryData
        case lastStudyActivityAt, isPinned, folderID, cards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        completedStudySessions = try container.decodeIfPresent(
            Int.self,
            forKey: .completedStudySessions
        ) ?? 0
        activeStudySessionData = try container.decodeIfPresent(
            Data.self,
            forKey: .activeStudySessionData
        )
        studyHistoryData = try container.decodeIfPresent(Data.self, forKey: .studyHistoryData)
        lastStudyActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastStudyActivityAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        cards = try container.decode([BackupCardDTO].self, forKey: .cards)
    }

    var currentDTO: BackupDeckDTO {
        BackupDeckDTO(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastOpenedAt: lastOpenedAt,
            completedStudySessions: completedStudySessions,
            activeStudySessionData: activeStudySessionData,
            studyHistoryData: studyHistoryData,
            lastStudyActivityAt: lastStudyActivityAt,
            isPinned: isPinned,
            folderID: folderID,
            cards: cards,
            testConfiguration: .useFlashcards
        )
    }
}

private struct LegacyBackupEnvelopeV1: Decodable {
    var schemaVersion: Int
    var exportedAt: Date
    var scope: BackupScope
    var folders: [BackupFolderDTO]
    var decks: [LegacyBackupDeckDTO]
}

private struct BackupVersionHeader: Decodable {
    var schemaVersion: Int
}

struct BackupEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var exportedAt: Date
    var scope: BackupScope
    var folders: [BackupFolderDTO]
    var decks: [BackupDeckDTO]

    init(
        schemaVersion: Int = currentSchemaVersion,
        exportedAt: Date = .now,
        scope: BackupScope,
        folders: [BackupFolderDTO],
        decks: [BackupDeckDTO]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.scope = scope
        self.folders = folders
        self.decks = decks
    }
}

enum BackupCodecError: LocalizedError {
    case unsupportedSchema(Int)
    case emptyBackup
    case invalidTestConfiguration

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            L10n.format("backup.error.unsupported_schema", Int64(version))
        case .emptyBackup:
            L10n.text("backup.error.empty")
        case .invalidTestConfiguration:
            L10n.text("backup.error.invalid_test_configuration")
        }
    }
}

enum BackupCodec {
    static func encode(_ envelope: BackupEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var currentEnvelope = envelope
        currentEnvelope.schemaVersion = BackupEnvelope.currentSchemaVersion
        return try encoder.encode(currentEnvelope)
    }

    static func decode(_ data: Data) throws -> BackupEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let header = try decoder.decode(BackupVersionHeader.self, from: data)
        let envelope: BackupEnvelope
        switch header.schemaVersion {
        case 1:
            let legacy = try decoder.decode(LegacyBackupEnvelopeV1.self, from: data)
            envelope = BackupEnvelope(
                exportedAt: legacy.exportedAt,
                scope: legacy.scope,
                folders: legacy.folders,
                decks: legacy.decks.map(\.currentDTO)
            )
        case BackupEnvelope.currentSchemaVersion:
            envelope = try decoder.decode(BackupEnvelope.self, from: data)
        default:
            throw BackupCodecError.unsupportedSchema(header.schemaVersion)
        }

        guard !envelope.decks.isEmpty || !envelope.folders.isEmpty else {
            throw BackupCodecError.emptyBackup
        }
        try validateTestConfigurations(in: envelope)
        return envelope
    }

    private static func validateTestConfigurations(in envelope: BackupEnvelope) throws {
        do {
            for deck in envelope.decks {
                let referencedCardIDs = Set(
                    deck.testConfiguration.multipleChoice.map(\.sourceCardID)
                    + deck.testConfiguration.trueFalse.map(\.sourceCardID)
                )
                _ = try deck.testConfiguration.validated(
                    validCardIDs: Set(deck.cards.map(\.id)).union(referencedCardIDs)
                )
            }
        } catch {
            throw BackupCodecError.invalidTestConfiguration
        }
    }
}

enum BackupMerger {
    static func merge(
        local: BackupEnvelope,
        incoming: BackupEnvelope
    ) throws -> BackupEnvelope {
        var folders = Dictionary(uniqueKeysWithValues: local.folders.map { ($0.id, $0) })
        for folder in incoming.folders {
            folders[folder.id] = folder
        }

        var decks = Dictionary(uniqueKeysWithValues: local.decks.map { ($0.id, $0) })
        for incomingDeck in incoming.decks {
            guard let localDeck = decks[incomingDeck.id] else {
                decks[incomingDeck.id] = incomingDeck
                continue
            }
            var cards = Dictionary(uniqueKeysWithValues: localDeck.cards.map { ($0.id, $0) })
            for card in incomingDeck.cards {
                cards[card.id] = card
            }
            var mergedDeck = incomingDeck
            mergedDeck.lastOpenedAt = incomingDeck.lastOpenedAt ?? localDeck.lastOpenedAt
            mergedDeck.cards = cards.values.sorted { $0.position < $1.position }
            mergedDeck.testConfiguration = localDeck.testConfiguration.mergingQuestions(
                from: incomingDeck.testConfiguration
            )
            decks[incomingDeck.id] = mergedDeck
        }

        let result = BackupEnvelope(
            exportedAt: incoming.exportedAt,
            scope: .database,
            folders: folders.values.sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortOrder < $1.sortOrder
            },
            decks: decks.values.sorted { $0.createdAt < $1.createdAt }
        )
        do {
            for deck in result.decks {
                _ = try deck.testConfiguration.validated(
                    validCardIDs: Set(deck.cards.map(\.id))
                )
            }
        } catch {
            throw BackupCodecError.invalidTestConfiguration
        }
        return result
    }
}
