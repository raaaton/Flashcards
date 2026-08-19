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

struct StudySessionItem: Identifiable, Equatable, Sendable {
    let card: StudyCardSnapshot
    let isReversed: Bool

    var id: UUID { card.id }
    var front: String { isReversed ? card.definition : card.term }
    var back: String { isReversed ? card.term : card.definition }
}

struct StudySessionState: Equatable, Sendable {
    let direction: StudyDirection
    private let initialCardCount: Int

    private(set) var items: [StudySessionItem]
    private(set) var currentIndex = 0
    private(set) var cardsSeen = 0
    private(set) var correctAnswers = 0
    private(set) var reviewAnswers = 0
    private(set) var isComplete = false

    init(cards: [StudyCardSnapshot], direction: StudyDirection, shuffle: Bool = true) {
        self.direction = direction
        initialCardCount = cards.count
        items = Self.makeItems(cards: cards, direction: direction, shuffle: shuffle)
        isComplete = cards.isEmpty
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

    @discardableResult
    mutating func answer(_ outcome: StudyOutcome) -> UUID? {
        guard let item = currentItem, !isComplete else { return nil }
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
