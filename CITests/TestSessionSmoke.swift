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

        var resumableState = TestSessionState(questions: [written, questions[1]])
        resumableState.submit(answer: "faux")
        let activeSnapshot = ActiveTestSessionSnapshot(
            deckID: UUID(),
            sessionNumber: 3,
            selectedTypes: [.written, .trueFalse],
            direction: .definitionToTerm,
            shuffle: false,
            starredOnly: true,
            sessionSize: .twenty,
            state: resumableState
        )
        let activeData = try! TestSessionPersistence.encode(activeSnapshot)
        let restoredSnapshot = TestSessionPersistence.decode(
            activeData,
            deckID: activeSnapshot.deckID
        )
        precondition(restoredSnapshot == activeSnapshot)
        precondition(restoredSnapshot?.state.currentAnswer?.givenAnswer == "faux")
        precondition(TestSessionPersistence.decode(activeData, deckID: UUID()) == nil)

        var completedState = resumableState
        precondition(completedState.advance())
        completedState.submit(answer: completedState.currentQuestion!.correctAnswer)
        precondition(completedState.advance())
        let completedSnapshot = ActiveTestSessionSnapshot(
            deckID: activeSnapshot.deckID,
            sessionNumber: 3,
            selectedTypes: [.written, .trueFalse],
            direction: .definitionToTerm,
            shuffle: false,
            starredOnly: true,
            sessionSize: .twenty,
            state: completedState
        )
        let completedData = try! TestSessionPersistence.encode(completedSnapshot)
        precondition(TestSessionPersistence.decode(
            completedData,
            deckID: activeSnapshot.deckID
        ) == nil)

        let secondWritten = TestQuestion(
            id: UUID(),
            cardID: cards[0].id,
            type: .written,
            prompt: "Deuxième question",
            secondaryText: nil,
            correctAnswer: "Deuxième réponse",
            referenceAnswer: "Deuxième réponse",
            choices: []
        )
        var sharedSourceSession = TestSessionState(questions: [written, secondWritten])
        sharedSourceSession.submit(answer: written.correctAnswer)
        precondition(sharedSourceSession.masteryStatus(for: cards[0].id) == nil)
        precondition(sharedSourceSession.advance())
        sharedSourceSession.submit(answer: "incorrect")
        precondition(sharedSourceSession.masteryStatus(for: cards[0].id) == false)
        precondition(sharedSourceSession.masteryStatus(for: cards[1].id) == nil)

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

        let authored = DeckTestConfiguration(
            mode: .manual,
            multipleChoice: [
                AuthoredMultipleChoiceQuestion(
                    sourceCardID: cards[0].id,
                    prompt: "QCM 1",
                    choices: ["Bonne", "Fausse A", "Fausse B", "Fausse C"],
                    correctChoiceIndex: 0
                ),
                AuthoredMultipleChoiceQuestion(
                    sourceCardID: cards[0].id,
                    prompt: "QCM 2",
                    choices: ["A", "B"],
                    correctChoiceIndex: 1
                )
            ],
            trueFalse: [
                AuthoredTrueFalseQuestion(
                    sourceCardID: cards[1].id,
                    statement: "Énoncé fixe",
                    correctAnswer: false
                )
            ]
        )
        let availability = AuthoredTestQuestionFactory.availability(
            cards: cards,
            configuration: authored
        )
        precondition(availability.multipleChoice == 2)
        precondition(availability.trueFalse == 1)
        precondition(availability.written == 5)

        let mixedAuthored = AuthoredTestQuestionFactory.makeQuestions(
            cards: cards,
            configuration: authored,
            types: Set(TestQuestionType.allCases),
            count: 5,
            direction: .termToDefinition,
            shuffle: false
        )
        precondition(mixedAuthored.count == 5)
        precondition(mixedAuthored.map(\.type) == [
            .multipleChoice, .trueFalse, .written, .multipleChoice, .written
        ])
        precondition(mixedAuthored.filter { $0.type == .multipleChoice }.count == 2)
        precondition(mixedAuthored.filter { $0.type == .trueFalse }.count == 1)
        precondition(mixedAuthored.first { $0.type == .trueFalse }?.referenceAnswer == nil)

        var editableSession = TestSessionState(questions: mixedAuthored)
        var editedQuestion = mixedAuthored[0]
        editedQuestion.prompt = "QCM modifié"
        precondition(editableSession.replaceCurrentQuestion(with: editedQuestion))
        precondition(editableSession.currentQuestion?.prompt == "QCM modifié")

        var invalidReplacement = editedQuestion
        invalidReplacement.prompt = "Mauvaise identité"
        invalidReplacement = TestQuestion(
            id: UUID(),
            cardID: invalidReplacement.cardID,
            type: invalidReplacement.type,
            prompt: invalidReplacement.prompt,
            secondaryText: invalidReplacement.secondaryText,
            correctAnswer: invalidReplacement.correctAnswer,
            referenceAnswer: invalidReplacement.referenceAnswer,
            choices: invalidReplacement.choices
        )
        precondition(!editableSession.replaceCurrentQuestion(with: invalidReplacement))
        editableSession.submit(answer: editedQuestion.correctAnswer)
        precondition(!editableSession.replaceCurrentQuestion(with: editedQuestion))

        let authoredForward = AuthoredTestQuestionFactory.makeQuestions(
            cards: cards,
            configuration: authored,
            types: [.multipleChoice, .trueFalse, .written],
            count: 3,
            direction: .termToDefinition,
            shuffle: false
        )
        let authoredReverse = AuthoredTestQuestionFactory.makeQuestions(
            cards: cards,
            configuration: authored,
            types: [.multipleChoice, .trueFalse, .written],
            count: 3,
            direction: .definitionToTerm,
            shuffle: false
        )
        precondition(authoredForward[0].prompt == authoredReverse[0].prompt)
        precondition(authoredForward[1].prompt == authoredReverse[1].prompt)
        precondition(authoredForward[2].correctAnswer == cards[0].definition)
        precondition(authoredReverse[2].correctAnswer == cards[0].term)

        let favoriteSubset = [cards[1]]
        let favoriteAvailability = AuthoredTestQuestionFactory.availability(
            cards: favoriteSubset,
            configuration: authored
        )
        precondition(favoriteAvailability.multipleChoice == 0)
        precondition(favoriteAvailability.trueFalse == 1)
        let favoriteQuestions = AuthoredTestQuestionFactory.makeQuestions(
            cards: favoriteSubset,
            configuration: authored,
            types: [.multipleChoice, .trueFalse],
            count: 10,
            direction: .random,
            shuffle: false
        )
        precondition(favoriteQuestions.count == 1)
        precondition(favoriteQuestions[0].type == .trueFalse)

        let shuffledChoices = AuthoredTestQuestionFactory.makeQuestions(
            cards: cards,
            configuration: authored,
            types: [.multipleChoice],
            count: 2,
            direction: .random,
            shuffle: true
        )
        precondition(shuffledChoices.count == 2)
        precondition(shuffledChoices.allSatisfy { $0.choices.contains($0.correctAnswer) })

        var retrySession = TestSessionState(questions: [written])
        retrySession.submit(answer: "faux")
        retrySession.retryErrors()
        precondition(retrySession.questions == [written])
        precondition(retrySession.answers.isEmpty)

        print("TestSessionState smoke tests passed")
    }
}
