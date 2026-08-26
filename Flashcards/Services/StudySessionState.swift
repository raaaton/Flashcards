import Foundation

enum StudyDirection: String, CaseIterable, Identifiable, Codable, Sendable {
    case termToDefinition
    case definitionToTerm
    case random

    var id: Self { self }

    var title: String {
        switch self {
        case .termToDefinition: L10n.text("study.direction.term_definition")
        case .definitionToTerm: L10n.text("study.direction.definition_term")
        case .random: L10n.text("study.direction.random")
        }
    }
}

enum StudyOutcome: String, Equatable, Codable, Sendable {
    case knew
    case review
}

enum SessionSize: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case ten
    case twenty
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .ten: "10"
        case .twenty: "20"
        case .all: L10n.text("session.size.all")
        }
    }

    var limit: Int? {
        switch self {
        case .ten: 10
        case .twenty: 20
        case .all: nil
        }
    }
}

struct StudyCardProgressSnapshot: Equatable, Codable, Sendable {
    let mastered: Bool
    let timesStudied: Int
    let timesCorrect: Int
}

struct StudyJudgment: Equatable, Codable, Sendable {
    let cardID: UUID
    let outcome: StudyOutcome
    let previousProgress: StudyCardProgressSnapshot
}

struct StudyCardSnapshot: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let term: String
    let definition: String
}

struct StudySessionItem: Identifiable, Equatable, Codable, Sendable {
    let card: StudyCardSnapshot
    let isReversed: Bool

    var id: UUID { card.id }
    var front: String { isReversed ? card.definition : card.term }
    var back: String { isReversed ? card.term : card.definition }
}

struct StudySessionState: Equatable, Codable, Sendable {
    let direction: StudyDirection
    let shuffle: Bool
    let sessionSize: SessionSize?
    let starredOnly: Bool?
    private let initialCardCount: Int

    private(set) var items: [StudySessionItem]
    private(set) var currentIndex = 0
    private(set) var cardsSeen = 0
    private(set) var correctAnswers = 0
    private(set) var reviewAnswers = 0
    private(set) var isComplete = false
    private(set) var judgments: [StudyJudgment]?

    init(
        cards: [StudyCardSnapshot],
        direction: StudyDirection,
        shuffle: Bool = true,
        sessionSize: SessionSize = .all,
        starredOnly: Bool = false
    ) {
        self.direction = direction
        self.shuffle = shuffle
        self.sessionSize = sessionSize
        self.starredOnly = starredOnly
        initialCardCount = cards.count
        items = Self.makeItems(cards: cards, direction: direction, shuffle: shuffle)
        isComplete = cards.isEmpty
        judgments = []
    }

    var currentItem: StudySessionItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var remainingCards: Int {
        max(items.count - currentIndex, 0)
    }

    var totalCards: Int {
        initialCardCount
    }

    var masteredInSession: Int {
        correctAnswers
    }

    var visibleItems: [StudySessionItem] {
        guard items.indices.contains(currentIndex) else { return [] }
        return Array(items[currentIndex...].prefix(2))
    }

    var successRate: Int {
        guard cardsSeen > 0 else { return 0 }
        return Int((Double(correctAnswers) / Double(cardsSeen) * 100).rounded())
    }

    var canUndo: Bool {
        !isComplete && !(judgments ?? []).isEmpty
    }

    @discardableResult
    mutating func updateCard(id: UUID, term: String, definition: String) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        let item = items[index]
        items[index] = StudySessionItem(
            card: StudyCardSnapshot(id: id, term: term, definition: definition),
            isReversed: item.isReversed
        )
        return true
    }

    var reviewedCardIDs: [UUID] {
        (judgments ?? []).compactMap { judgment in
            judgment.outcome == .review ? judgment.cardID : nil
        }
    }

    @discardableResult
    mutating func answer(
        _ outcome: StudyOutcome,
        previousProgress: StudyCardProgressSnapshot = .init(
            mastered: false,
            timesStudied: 0,
            timesCorrect: 0
        )
    ) -> UUID? {
        guard let item = currentItem, !isComplete else { return nil }
        if judgments == nil { judgments = [] }
        judgments?.append(
            StudyJudgment(
                cardID: item.id,
                outcome: outcome,
                previousProgress: previousProgress
            )
        )
        cardsSeen += 1

        switch outcome {
        case .knew:
            correctAnswers += 1
        case .review:
            reviewAnswers += 1
        }

        currentIndex += 1
        isComplete = currentIndex >= items.count
        return item.card.id
    }

    @discardableResult
    mutating func undoLastAnswer() -> StudyJudgment? {
        guard !isComplete, let judgment = judgments?.popLast(), currentIndex > 0 else {
            return nil
        }

        currentIndex -= 1
        cardsSeen = max(cardsSeen - 1, 0)
        switch judgment.outcome {
        case .knew:
            correctAnswers = max(correctAnswers - 1, 0)
        case .review:
            reviewAnswers = max(reviewAnswers - 1, 0)
        }
        return judgment
    }

    private static func makeItems(
        cards: [StudyCardSnapshot],
        direction: StudyDirection,
        shuffle: Bool
    ) -> [StudySessionItem] {
        let items = cards.map { card in
            let isReversed = switch direction {
            case .termToDefinition: false
            case .definitionToTerm: true
            case .random: Bool.random()
            }
            return StudySessionItem(card: card, isReversed: isReversed)
        }
        return shuffle ? items.shuffled() : items
    }
}

struct ActiveStudySessionSnapshot: Equatable, Codable, Sendable {
    let deckID: UUID
    let sessionNumber: Int
    var state: StudySessionState
}

enum StudySessionPersistence {
    static func encode(_ snapshot: ActiveStudySessionSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    static func decode(_ data: Data, deckID: UUID) -> ActiveStudySessionSnapshot? {
        guard let snapshot = try? JSONDecoder().decode(
            ActiveStudySessionSnapshot.self,
            from: data
        ), snapshot.deckID == deckID, !snapshot.state.isComplete else {
            return nil
        }
        return snapshot
    }
}
