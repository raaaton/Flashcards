import Foundation

enum StudyDirection: String, CaseIterable, Identifiable, Sendable {
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

enum StudyOutcome: Equatable, Sendable {
    case knew
    case review
}

struct StudyCardSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let term: String
    let definition: String
}

struct StudyRoundItem: Identifiable, Equatable, Sendable {
    let card: StudyCardSnapshot
    let isReversed: Bool

    var id: UUID { card.id }
    var front: String { isReversed ? card.definition : card.term }
    var back: String { isReversed ? card.term : card.definition }
}

struct StudySessionState: Equatable, Sendable {
    let direction: StudyDirection
    private let shufflesRounds: Bool
    private let initialCardCount: Int

    private(set) var currentRound: [StudyRoundItem]
    private(set) var nextRound: [StudyCardSnapshot] = []
    private(set) var currentIndex = 0
    private(set) var roundNumber = 1
    private(set) var cardsSeen = 0
    private(set) var correctAnswers = 0
    private(set) var isComplete = false

    init(cards: [StudyCardSnapshot], direction: StudyDirection, shuffle: Bool = true) {
        self.direction = direction
        shufflesRounds = shuffle
        initialCardCount = cards.count
        currentRound = Self.makeRound(cards: cards, direction: direction, shuffle: shuffle)
        isComplete = cards.isEmpty
    }

    var currentItem: StudyRoundItem? {
        guard currentRound.indices.contains(currentIndex) else { return nil }
        return currentRound[currentIndex]
    }

    var remainingInRound: Int {
        max(currentRound.count - currentIndex, 0)
    }

    var totalCards: Int {
        initialCardCount
    }

    var masteredInSession: Int {
        correctAnswers
    }

    var visibleItems: [StudyRoundItem] {
        guard currentRound.indices.contains(currentIndex) else { return [] }
        return Array(currentRound[currentIndex...].prefix(2))
    }

    var successRate: Int {
        guard cardsSeen > 0 else { return 0 }
        return Int((Double(correctAnswers) / Double(cardsSeen) * 100).rounded())
    }

    @discardableResult
    mutating func answer(_ outcome: StudyOutcome) -> UUID? {
        guard let item = currentItem, !isComplete else { return nil }
        cardsSeen += 1

        switch outcome {
        case .knew:
            correctAnswers += 1
        case .review:
            nextRound.append(item.card)
        }

        currentIndex += 1
        if currentIndex >= currentRound.count {
            advanceRound()
        }
        return item.card.id
    }

    mutating func restart(with cards: [StudyCardSnapshot]) {
        self = StudySessionState(cards: cards, direction: direction, shuffle: shufflesRounds)
    }

    private mutating func advanceRound() {
        guard !nextRound.isEmpty else {
            isComplete = true
            return
        }

        currentRound = Self.makeRound(
            cards: nextRound,
            direction: direction,
            shuffle: shufflesRounds
        )
        nextRound.removeAll(keepingCapacity: true)
        currentIndex = 0
        roundNumber += 1
    }

    private static func makeRound(
        cards: [StudyCardSnapshot],
        direction: StudyDirection,
        shuffle: Bool
    ) -> [StudyRoundItem] {
        let items = cards.map { card in
            let isReversed = switch direction {
            case .termToDefinition: false
            case .definitionToTerm: true
            case .random: Bool.random()
            }
            return StudyRoundItem(card: card, isReversed: isReversed)
        }
        return shuffle ? items.shuffled() : items
    }
}
