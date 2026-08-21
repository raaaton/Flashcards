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
    var timesStudied: Int
    var timesCorrect: Int
    var isStarred: Bool

    init(
        id: UUID,
        term: String,
        definition: String,
        position: Int,
        mastered: Bool,
        timesStudied: Int,
        timesCorrect: Int,
        isStarred: Bool = false
    ) {
        self.id = id
        self.term = term
        self.definition = definition
        self.position = position
        self.mastered = mastered
        self.timesStudied = timesStudied
        self.timesCorrect = timesCorrect
        self.isStarred = isStarred
    }

    private enum CodingKeys: String, CodingKey {
        case id, term, definition, position, mastered, timesStudied, timesCorrect, isStarred
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        term = try container.decode(String.self, forKey: .term)
        definition = try container.decode(String.self, forKey: .definition)
        position = try container.decode(Int.self, forKey: .position)
        mastered = try container.decode(Bool.self, forKey: .mastered)
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
    var studyHistoryData: Data?
    var lastStudyActivityAt: Date?
    var isPinned: Bool
    var folderID: UUID?
    var cards: [BackupCardDTO]

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        lastOpenedAt: Date? = nil,
        completedStudySessions: Int = 0,
        activeStudySessionData: Data? = nil,
        studyHistoryData: Data? = nil,
        lastStudyActivityAt: Date? = nil,
        isPinned: Bool = false,
        folderID: UUID?,
        cards: [BackupCardDTO]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.completedStudySessions = completedStudySessions
        self.activeStudySessionData = activeStudySessionData
        self.studyHistoryData = studyHistoryData
        self.lastStudyActivityAt = lastStudyActivityAt
        self.isPinned = isPinned
        self.folderID = folderID
        self.cards = cards
    }

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
}

struct BackupEnvelopeV1: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

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

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            L10n.format("backup.error.unsupported_schema", Int64(version))
        case .emptyBackup:
            L10n.text("backup.error.empty")
        }
    }
}

enum BackupCodec {
    static func encode(_ envelope: BackupEnvelopeV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(envelope)
    }

    static func decode(_ data: Data) throws -> BackupEnvelopeV1 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(BackupEnvelopeV1.self, from: data)
        guard envelope.schemaVersion == BackupEnvelopeV1.currentSchemaVersion else {
            throw BackupCodecError.unsupportedSchema(envelope.schemaVersion)
        }
        guard !envelope.decks.isEmpty || !envelope.folders.isEmpty else {
            throw BackupCodecError.emptyBackup
        }
        return envelope
    }
}

enum BackupMerger {
    static func merge(
        local: BackupEnvelopeV1,
        incoming: BackupEnvelopeV1
    ) -> BackupEnvelopeV1 {
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
            decks[incomingDeck.id] = mergedDeck
        }

        return BackupEnvelopeV1(
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
    }
}
