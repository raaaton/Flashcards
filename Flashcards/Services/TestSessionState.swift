import Foundation

enum TestQuestionType: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case multipleChoice
    case trueFalse
    case written

    var id: Self { self }

    var title: String {
        switch self {
        case .multipleChoice: L10n.text("test.type.multiple_choice")
        case .trueFalse: L10n.text("test.type.true_false")
        case .written: L10n.text("test.type.written")
        }
    }
}

struct TestCardSnapshot: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let term: String
    let definition: String
}

struct TestQuestion: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let cardID: UUID
    let type: TestQuestionType
    var prompt: String
    var secondaryText: String?
    var correctAnswer: String
    var referenceAnswer: String?
    var choices: [String]
}

struct TestAnswerRecord: Identifiable, Equatable, Codable, Sendable {
    let question: TestQuestion
    let givenAnswer: String
    var isCorrect: Bool
    var wasOverridden: Bool

    var id: UUID { question.id }
}

enum TestQuestionFactory {
    static func makeQuestions(
        cards: [TestCardSnapshot],
        types: Set<TestQuestionType>,
        count: Int,
        direction: StudyDirection,
        shuffle: Bool = true
    ) -> [TestQuestion] {
        let enabledTypes = TestQuestionType.allCases.filter(types.contains)
        guard !cards.isEmpty, !enabledTypes.isEmpty, count > 0 else { return [] }

        let cardPool = shuffle ? cards.shuffled() : cards
        let selectedCards = Array(cardPool.prefix(min(count, cards.count)))
        var questions = selectedCards.enumerated().map { index, card in
            makeQuestion(
                for: card,
                type: enabledTypes[index % enabledTypes.count],
                allCards: cards,
                direction: direction,
                shuffle: shuffle,
                index: index
            )
        }
        if shuffle {
            questions.shuffle()
        }
        return questions
    }

    static func normalize(_ value: String) -> String {
        AuthoredTestText.normalize(value)
    }

    private static func makeQuestion(
        for card: TestCardSnapshot,
        type: TestQuestionType,
        allCards: [TestCardSnapshot],
        direction: StudyDirection,
        shuffle: Bool,
        index: Int
    ) -> TestQuestion {
        let isReversed = switch direction {
        case .termToDefinition: false
        case .definitionToTerm: true
        case .random: shuffle ? Bool.random() : index.isMultiple(of: 2)
        }
        let prompt = isReversed ? card.definition : card.term
        let answer = isReversed ? card.term : card.definition

        switch type {
        case .multipleChoice:
            var seen = Set([normalize(answer)])
            var distractors: [String] = []
            let candidates = shuffle ? allCards.shuffled() : allCards
            for candidate in candidates where candidate.id != card.id {
                let candidateAnswer = isReversed ? candidate.term : candidate.definition
                if seen.insert(normalize(candidateAnswer)).inserted {
                    distractors.append(candidateAnswer)
                }
                if distractors.count == 3 { break }
            }
            var choices = [answer] + distractors
            if shuffle { choices.shuffle() }
            return TestQuestion(
                id: UUID(),
                cardID: card.id,
                type: type,
                prompt: prompt,
                secondaryText: nil,
                correctAnswer: answer,
                referenceAnswer: answer,
                choices: choices
            )

        case .trueFalse:
            let candidates = allCards.filter { candidate in
                guard candidate.id != card.id else { return false }
                let candidateAnswer = isReversed ? candidate.term : candidate.definition
                return normalize(candidateAnswer) != normalize(answer)
            }
            let shouldBeTrue = candidates.isEmpty || (shuffle ? Bool.random() : index.isMultiple(of: 2))
            let proposedAnswer: String
            if shouldBeTrue {
                proposedAnswer = answer
            } else {
                let candidate = shuffle ? candidates.randomElement()! : candidates[0]
                proposedAnswer = isReversed ? candidate.term : candidate.definition
            }
            return TestQuestion(
                id: UUID(),
                cardID: card.id,
                type: type,
                prompt: prompt,
                secondaryText: proposedAnswer,
                correctAnswer: shouldBeTrue ? "Vrai" : "Faux",
                referenceAnswer: answer,
                choices: ["Vrai", "Faux"]
            )

        case .written:
            return TestQuestion(
                id: UUID(),
                cardID: card.id,
                type: type,
                prompt: prompt,
                secondaryText: nil,
                correctAnswer: answer,
                referenceAnswer: answer,
                choices: []
            )
        }
    }
}

struct AuthoredTestAvailability: Equatable, Sendable {
    let multipleChoice: Int
    let trueFalse: Int
    let written: Int

    func count(for type: TestQuestionType) -> Int {
        switch type {
        case .multipleChoice: multipleChoice
        case .trueFalse: trueFalse
        case .written: written
        }
    }

    func total(for types: Set<TestQuestionType>) -> Int {
        types.reduce(into: 0) { total, type in
            total += count(for: type)
        }
    }
}

enum AuthoredTestQuestionFactory {
    static func availability(
        cards: [TestCardSnapshot],
        configuration: DeckTestConfiguration
    ) -> AuthoredTestAvailability {
        let cardIDs = Set(cards.map(\.id))
        return AuthoredTestAvailability(
            multipleChoice: configuration.multipleChoice.count(where: {
                cardIDs.contains($0.sourceCardID)
            }),
            trueFalse: configuration.trueFalse.count(where: {
                cardIDs.contains($0.sourceCardID)
            }),
            written: cards.count
        )
    }

    static func makeQuestions(
        cards: [TestCardSnapshot],
        configuration: DeckTestConfiguration,
        types: Set<TestQuestionType>,
        count: Int,
        direction: StudyDirection,
        shuffle: Bool
    ) -> [TestQuestion] {
        guard configuration.mode != .useFlashcards, !types.isEmpty, count > 0 else {
            return []
        }

        let cardIDs = Set(cards.map(\.id))
        var pools: [TestQuestionType: [TestQuestion]] = [:]

        if types.contains(.multipleChoice) {
            pools[.multipleChoice] = configuration.multipleChoice.compactMap { question in
                guard cardIDs.contains(question.sourceCardID),
                      question.choices.indices.contains(question.correctChoiceIndex) else {
                    return nil
                }
                var choices = question.choices
                let correctAnswer = choices[question.correctChoiceIndex]
                if shuffle { choices.shuffle() }
                return TestQuestion(
                    id: question.id,
                    cardID: question.sourceCardID,
                    type: .multipleChoice,
                    prompt: question.prompt,
                    secondaryText: nil,
                    correctAnswer: correctAnswer,
                    referenceAnswer: nil,
                    choices: choices
                )
            }
        }

        if types.contains(.trueFalse) {
            pools[.trueFalse] = configuration.trueFalse.compactMap { question in
                guard cardIDs.contains(question.sourceCardID) else { return nil }
                return TestQuestion(
                    id: question.id,
                    cardID: question.sourceCardID,
                    type: .trueFalse,
                    prompt: question.statement,
                    secondaryText: nil,
                    correctAnswer: question.correctAnswer ? "Vrai" : "Faux",
                    referenceAnswer: nil,
                    choices: ["Vrai", "Faux"]
                )
            }
        }

        if types.contains(.written) {
            pools[.written] = TestQuestionFactory.makeQuestions(
                cards: cards,
                types: [.written],
                count: cards.count,
                direction: direction,
                shuffle: shuffle
            )
        }

        if shuffle {
            for type in TestQuestionType.allCases where type != .written {
                pools[type]?.shuffle()
            }
        }

        let enabledTypes = TestQuestionType.allCases.filter(types.contains)
        var offsets = Dictionary(uniqueKeysWithValues: enabledTypes.map { ($0, 0) })
        var questions: [TestQuestion] = []

        while questions.count < count {
            var appendedQuestion = false
            for type in enabledTypes where questions.count < count {
                let offset = offsets[type, default: 0]
                guard let pool = pools[type], pool.indices.contains(offset) else { continue }
                questions.append(pool[offset])
                offsets[type] = offset + 1
                appendedQuestion = true
            }
            if !appendedQuestion { break }
        }

        if shuffle { questions.shuffle() }
        return questions
    }
}

struct TestSessionState: Equatable, Codable, Sendable {
    private(set) var questions: [TestQuestion]
    private(set) var currentIndex = 0
    private(set) var answers: [TestAnswerRecord] = []
    private(set) var currentAnswer: TestAnswerRecord?

    init(questions: [TestQuestion]) {
        self.questions = questions
    }

    var currentQuestion: TestQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var isComplete: Bool {
        currentIndex >= questions.count
    }

    var isLastQuestion: Bool {
        !questions.isEmpty && currentIndex == questions.count - 1
    }

    var correctCount: Int {
        answers.count(where: \.isCorrect)
    }

    var score: Int {
        guard !answers.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(answers.count) * 100).rounded())
    }

    func masteryStatus(for cardID: UUID) -> Bool? {
        let questionIDs = Set(
            questions.lazy
                .filter { $0.cardID == cardID }
                .map(\.id)
        )
        guard !questionIDs.isEmpty else { return nil }
        let linkedAnswers = answers.filter { questionIDs.contains($0.question.id) }
        guard linkedAnswers.count == questionIDs.count else { return nil }
        return linkedAnswers.allSatisfy(\.isCorrect)
    }

    @discardableResult
    mutating func submit(answer: String) -> TestAnswerRecord? {
        guard let question = currentQuestion, currentAnswer == nil else { return nil }
        let isCorrect = TestQuestionFactory.normalize(answer)
            == TestQuestionFactory.normalize(question.correctAnswer)
        let record = TestAnswerRecord(
            question: question,
            givenAnswer: answer,
            isCorrect: isCorrect,
            wasOverridden: false
        )
        answers.append(record)
        currentAnswer = record
        return record
    }

    @discardableResult
    mutating func advance() -> Bool {
        guard currentAnswer != nil else { return false }
        currentAnswer = nil
        currentIndex += 1
        return true
    }

    @discardableResult
    mutating func overrideWrittenAnswer(questionID: UUID) -> UUID? {
        guard let index = answers.firstIndex(where: { $0.question.id == questionID }),
              answers[index].question.type == .written,
              !answers[index].isCorrect else { return nil }
        answers[index].isCorrect = true
        answers[index].wasOverridden = true
        return answers[index].question.cardID
    }

    mutating func retryErrors() {
        questions = answers.filter { !$0.isCorrect }.map(\.question)
        currentIndex = 0
        answers = []
        currentAnswer = nil
    }

    mutating func refreshSourceCard(
        previous: TestCardSnapshot,
        updated: TestCardSnapshot,
        configurationMode: DeckTestCreationMode
    ) {
        guard previous.id == updated.id, currentAnswer == nil else { return }

        for index in questions.indices where index >= currentIndex {
            guard questions[index].cardID == updated.id else { continue }
            if configurationMode != .useFlashcards,
               questions[index].type != .written {
                continue
            }

            let promptMatchesDefinition = TestQuestionFactory.normalize(
                questions[index].prompt
            ) == TestQuestionFactory.normalize(previous.definition)
            let promptMatchesTerm = TestQuestionFactory.normalize(
                questions[index].prompt
            ) == TestQuestionFactory.normalize(previous.term)
            guard promptMatchesDefinition || promptMatchesTerm else { continue }

            let isReversed = promptMatchesDefinition && !promptMatchesTerm
            let oldAnswer = isReversed ? previous.term : previous.definition
            let newPrompt = isReversed ? updated.definition : updated.term
            let newAnswer = isReversed ? updated.term : updated.definition

            questions[index].prompt = newPrompt

            switch questions[index].type {
            case .multipleChoice:
                questions[index].correctAnswer = newAnswer
                questions[index].referenceAnswer = newAnswer
                questions[index].choices = questions[index].choices.map { choice in
                    TestQuestionFactory.normalize(choice)
                        == TestQuestionFactory.normalize(oldAnswer)
                        ? newAnswer
                        : choice
                }

            case .trueFalse:
                questions[index].referenceAnswer = newAnswer
                if questions[index].correctAnswer == "Vrai",
                   let secondaryText = questions[index].secondaryText,
                   TestQuestionFactory.normalize(secondaryText)
                    == TestQuestionFactory.normalize(oldAnswer) {
                    questions[index].secondaryText = newAnswer
                }

            case .written:
                questions[index].correctAnswer = newAnswer
                questions[index].referenceAnswer = newAnswer
            }
        }
    }
}

struct ActiveTestSessionSnapshot: Equatable, Codable, Sendable {
    let deckID: UUID
    let sessionNumber: Int
    let selectedTypes: Set<TestQuestionType>
    let direction: StudyDirection
    let shuffle: Bool
    let starredOnly: Bool
    let sessionSize: SessionSize
    let state: TestSessionState
}

enum TestSessionPersistence {
    static func encode(_ snapshot: ActiveTestSessionSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    static func decode(_ data: Data, deckID: UUID) -> ActiveTestSessionSnapshot? {
        guard let snapshot = try? JSONDecoder().decode(
            ActiveTestSessionSnapshot.self,
            from: data
        ),
        snapshot.deckID == deckID,
        !snapshot.state.isComplete,
        snapshot.state.currentIndex > 0 || !snapshot.state.answers.isEmpty else {
            return nil
        }
        return snapshot
    }
}
