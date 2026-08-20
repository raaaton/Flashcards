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
        let undone = session.undoLastAnswer()
        precondition(undone?.outcome == .knew)
        precondition(session.currentIndex == 1)
        precondition(session.cardsSeen == 1)
        precondition(session.correctAnswers == 0)
        precondition(session.reviewAnswers == 1)
        session.answer(.knew)

        let deckID = UUID()
        let suspended = ActiveStudySessionSnapshot(
            deckID: deckID,
            sessionNumber: 2,
            state: session
        )
        let restored = StudySessionPersistence.decode(
            try! StudySessionPersistence.encode(suspended),
            deckID: deckID
        )!
        precondition(restored.sessionNumber == 2)
        precondition(restored.state.currentIndex == 2)
        precondition(restored.state.remainingCards == 2)
        precondition(restored.state.currentItem?.id == session.currentItem?.id)
        precondition(restored.state.items.map(\.id) == session.items.map(\.id))
        precondition(restored.state.correctAnswers == 1)
        precondition(restored.state.reviewAnswers == 1)
        precondition(restored.state.canUndo)

        var multipleUndo = restored.state
        precondition(multipleUndo.undoLastAnswer()?.outcome == .knew)
        precondition(multipleUndo.undoLastAnswer()?.outcome == .review)
        precondition(multipleUndo.cardsSeen == 0)
        precondition(!multipleUndo.canUndo)

        let sized = StudySessionState(
            cards: cards,
            direction: .termToDefinition,
            shuffle: false,
            sessionSize: .ten,
            starredOnly: true
        )
        precondition(sized.sessionSize == .ten)
        precondition(sized.starredOnly == true)

        session = restored.state
        session.answer(.knew)
        session.answer(.knew)

        precondition(session.isComplete)
        precondition(session.cardsSeen == 4)
        precondition(session.undoLastAnswer() == nil)
        precondition(session.correctAnswers == 3)
        precondition(session.reviewAnswers == 1)
        precondition(session.successRate == 75)
        precondition(session.masteredInSession == 3)
        precondition(session.answer(.knew) == nil)
        precondition(session.cardsSeen == 4)

        let completed = ActiveStudySessionSnapshot(
            deckID: deckID,
            sessionNumber: 2,
            state: session
        )
        precondition(
            StudySessionPersistence.decode(
                try! StudySessionPersistence.encode(completed),
                deckID: deckID
            ) == nil
        )

        print("StudySessionState smoke tests passed")
    }
}
