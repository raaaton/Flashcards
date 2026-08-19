import Foundation

@main
enum TestSessionSmoke {
    static func main() {
        let cards = (1...5).map {
            TestCardSnapshot(id: UUID(), term: "Terme \($0)", definition: "Définition \($0)")
        }
        let questions = TestQuestionFactory.makeQuestions(
            cards: cards,
            types: Set(TestQuestionType.allCases),
            count: 5,
            direction: .termToDefinition,
            shuffle: false
        )
        precondition(questions.count == 5)
        precondition(questions.map(\.cardID) == cards.map(\.id))
        precondition(Set(questions.prefix(3).map(\.type)).count == 3)

        let qcm = questions.first { $0.type == .multipleChoice }!
        precondition((1...4).contains(qcm.choices.count))
        precondition(qcm.choices.contains(qcm.correctAnswer))
        precondition(Set(qcm.choices.map(TestQuestionFactory.normalize)).count == qcm.choices.count)

        precondition(TestQuestionFactory.normalize("  ÉLÈVE\n appliqué  ") == "eleve applique")

        let written = TestQuestion(
            id: UUID(),
            cardID: cards[0].id,
            type: .written,
            prompt: "Question",
            secondaryText: nil,
            correctAnswer: "Élève appliqué",
            referenceAnswer: "Élève appliqué",
            choices: []
        )
        var correctSession = TestSessionState(questions: [written])
        correctSession.submit(answer: "  eleve   APPLIQUÉ ")
        precondition(correctSession.correctCount == 1)
        precondition(correctSession.score == 100)
        precondition(!correctSession.isComplete)
        precondition(correctSession.submit(answer: "double") == nil)
        precondition(correctSession.currentIndex == 0)
        precondition(correctSession.advance())
        precondition(correctSession.isComplete)
        precondition(!correctSession.advance())

        var overrideSession = TestSessionState(questions: [written])
        overrideSession.submit(answer: "une formulation équivalente")
        precondition(overrideSession.score == 0)
        precondition(overrideSession.overrideWrittenAnswer(questionID: written.id) == cards[0].id)
        precondition(overrideSession.score == 100)

        let singleCardQuestions = TestQuestionFactory.makeQuestions(
            cards: [cards[0]],
            types: [.multipleChoice],
            count: 1,
            direction: .termToDefinition,
            shuffle: false
        )
        precondition(singleCardQuestions[0].choices.count == 1)

        print("TestSessionState smoke tests passed")
    }
}
