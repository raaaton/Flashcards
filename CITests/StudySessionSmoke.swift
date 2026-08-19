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

        let firstRoundIDs = session.currentRound.map(\.id)
        precondition(Set(firstRoundIDs).count == cards.count)
        precondition(session.roundNumber == 1)

        let reviewedID = session.currentItem?.id
        session.answer(.review)
        session.answer(.knew)
        session.answer(.knew)
        session.answer(.knew)

        precondition(!session.isComplete)
        precondition(session.roundNumber == 2)
        precondition(session.currentRound.count == 1)
        precondition(session.currentItem?.id == reviewedID)

        session.answer(.knew)
        precondition(session.isComplete)
        precondition(session.cardsSeen == 5)
        precondition(session.correctAnswers == 4)
        precondition(session.successRate == 80)

        session.restart(with: cards)
        precondition(!session.isComplete)
        precondition(session.cardsSeen == 0)
        precondition(session.currentRound.count == 4)

        print("StudySessionState smoke tests passed")
    }
}
