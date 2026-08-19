import Foundation

enum TestQuestionType: String, CaseIterable, Identifiable, Hashable, Sendable {
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

struct TestCardSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let term: String
    let definition: String
}

struct TestQuestion: Identifiable, Equatable, Sendable {
    let id: UUID
    let cardID: UUID
    let type: TestQuestionType
    let prompt: String
    let secondaryText: String?
    let correctAnswer: String
    let referenceAnswer: String
    let choices: [String]
}

struct TestAnswerRecord: Identifiable, Equatable, Sendable {
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
        let locale = Locale(identifier: "fr_FR")
        return value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: locale
            )
            .lowercased(with: locale)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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

struct TestSessionState: Equatable, Sendable {
    private(set) var questions: [TestQuestion]
    private(set) var currentIndex = 0
    private(set) var answers: [TestAnswerRecord] = []

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

    var correctCount: Int {
        answers.count(where: \.isCorrect)
    }

    var score: Int {
        guard !answers.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(answers.count) * 100).rounded())
    }

    @discardableResult
    mutating func submit(answer: String) -> TestAnswerRecord? {
        guard let question = currentQuestion else { return nil }
        let isCorrect = TestQuestionFactory.normalize(answer)
            == TestQuestionFactory.normalize(question.correctAnswer)
        let record = TestAnswerRecord(
            question: question,
            givenAnswer: answer,
            isCorrect: isCorrect,
            wasOverridden: false
        )
        answers.append(record)
        currentIndex += 1
        return record
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
    }
}
