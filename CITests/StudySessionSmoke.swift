import Foundation

@main
enum StudySessionSmoke {
    static func main() {
        let cards = (1...4).map {
            StudyCardSnapshot(id: UUID(), term: "T\($0)", definition: "D\($0)")
        }
        var session = StudySessionState(
            cards: cards,
            direction: .termToDefinition,
            shuffle: false
        )

        let sessionIDs = session.items.map(\.id)
        precondition(Set(sessionIDs).count == cards.count)
        precondition(session.totalCards == 4)
        precondition(session.masteredInSession == 0)
        precondition(session.visibleItems.map(\.id) == Array(sessionIDs.prefix(2)))

        let reviewedID = session.currentItem?.id
        session.answer(.review)
        precondition(!session.isComplete)
        precondition(session.currentItem?.id != reviewedID)
        session.answer(.knew)
        precondition(session.masteredInSession == 1)
        session.answer(.knew)
        session.answer(.knew)

        precondition(session.isComplete)
        precondition(session.cardsSeen == 4)
        precondition(session.correctAnswers == 3)
        precondition(session.reviewAnswers == 1)
        precondition(session.successRate == 75)
        precondition(session.masteredInSession == 3)
        precondition(session.answer(.knew) == nil)
        precondition(session.cardsSeen == 4)

        print("StudySessionState smoke tests passed")
    }
}
