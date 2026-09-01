import Foundation

enum DeckTestCreationMode: String, Codable, CaseIterable, Hashable, Sendable {
    case useFlashcards
    case ai
    case manual
}

struct AuthoredMultipleChoiceQuestion: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var sourceCardID: UUID
    var prompt: String
    var choices: [String]
    var correctChoiceIndex: Int

    init(
        id: UUID = UUID(),
        sourceCardID: UUID,
        prompt: String,
        choices: [String],
        correctChoiceIndex: Int
    ) {
        self.id = id
        self.sourceCardID = sourceCardID
        self.prompt = prompt
        self.choices = choices
        self.correctChoiceIndex = correctChoiceIndex
    }

    var correctAnswer: String? {
        guard choices.indices.contains(correctChoiceIndex) else { return nil }
        return choices[correctChoiceIndex]
    }

    func validated(validCardIDs: Set<UUID>) throws -> Self {
        guard validCardIDs.contains(sourceCardID) else {
            throw AuthoredTestValidationError.unknownSourceCard(sourceCardID)
        }

        let cleanPrompt = AuthoredTestText.clean(prompt)
        guard !cleanPrompt.isEmpty else {
            throw AuthoredTestValidationError.emptyPrompt
        }

        let cleanChoices = choices.map(AuthoredTestText.clean)
        guard (2...6).contains(cleanChoices.count), cleanChoices.allSatisfy({ !$0.isEmpty }) else {
            throw AuthoredTestValidationError.invalidChoiceCount
        }
        guard Set(cleanChoices.map(AuthoredTestText.normalize)).count == cleanChoices.count else {
            throw AuthoredTestValidationError.duplicateChoices
        }
        guard cleanChoices.indices.contains(correctChoiceIndex) else {
            throw AuthoredTestValidationError.invalidCorrectChoice
        }

        var copy = self
        copy.prompt = cleanPrompt
        copy.choices = cleanChoices
        return copy
    }
}

struct AuthoredTrueFalseQuestion: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var sourceCardID: UUID
    var statement: String
    var correctAnswer: Bool

    init(
        id: UUID = UUID(),
        sourceCardID: UUID,
        statement: String,
        correctAnswer: Bool
    ) {
        self.id = id
        self.sourceCardID = sourceCardID
        self.statement = statement
        self.correctAnswer = correctAnswer
    }

    func validated(validCardIDs: Set<UUID>) throws -> Self {
        guard validCardIDs.contains(sourceCardID) else {
            throw AuthoredTestValidationError.unknownSourceCard(sourceCardID)
        }
        let cleanStatement = AuthoredTestText.clean(statement)
        guard !cleanStatement.isEmpty else {
            throw AuthoredTestValidationError.emptyPrompt
        }

        var copy = self
        copy.statement = cleanStatement
        return copy
    }
}

struct DeckTestConfiguration: Codable, Equatable, Hashable, Sendable {
    var mode: DeckTestCreationMode
    var multipleChoice: [AuthoredMultipleChoiceQuestion]
    var trueFalse: [AuthoredTrueFalseQuestion]

    init(
        mode: DeckTestCreationMode = .useFlashcards,
        multipleChoice: [AuthoredMultipleChoiceQuestion] = [],
        trueFalse: [AuthoredTrueFalseQuestion] = []
    ) {
        self.mode = mode
        self.multipleChoice = multipleChoice
        self.trueFalse = trueFalse
    }

    static let useFlashcards = DeckTestConfiguration()

    var authoredQuestionCount: Int {
        multipleChoice.count + trueFalse.count
    }

    func validated(validCardIDs: Set<UUID>) throws -> Self {
        if mode == .useFlashcards {
            return .useFlashcards
        }

        var seenQuestionIDs = Set<UUID>()
        let cleanMultipleChoice = try multipleChoice.map { question in
            guard seenQuestionIDs.insert(question.id).inserted else {
                throw AuthoredTestValidationError.duplicateQuestionID(question.id)
            }
            return try question.validated(validCardIDs: validCardIDs)
        }
        let cleanTrueFalse = try trueFalse.map { question in
            guard seenQuestionIDs.insert(question.id).inserted else {
                throw AuthoredTestValidationError.duplicateQuestionID(question.id)
            }
            return try question.validated(validCardIDs: validCardIDs)
        }

        return DeckTestConfiguration(
            mode: mode,
            multipleChoice: cleanMultipleChoice,
            trueFalse: cleanTrueFalse
        )
    }

    func removingQuestions(linkedTo cardIDs: Set<UUID>) -> Self {
        guard !cardIDs.isEmpty else { return self }
        var copy = self
        copy.multipleChoice.removeAll { cardIDs.contains($0.sourceCardID) }
        copy.trueFalse.removeAll { cardIDs.contains($0.sourceCardID) }
        return copy
    }

    func questionsLinked(to cardIDs: Set<UUID>) -> Self {
        DeckTestConfiguration(
            mode: mode,
            multipleChoice: multipleChoice.filter { cardIDs.contains($0.sourceCardID) },
            trueFalse: trueFalse.filter { cardIDs.contains($0.sourceCardID) }
        )
    }

    func mergingQuestions(from incoming: Self) -> Self {
        guard incoming.mode != .useFlashcards else { return .useFlashcards }

        var multipleChoiceByID = Dictionary(uniqueKeysWithValues: multipleChoice.map { ($0.id, $0) })
        for question in incoming.multipleChoice {
            multipleChoiceByID[question.id] = question
        }

        var trueFalseByID = Dictionary(uniqueKeysWithValues: trueFalse.map { ($0.id, $0) })
        for question in incoming.trueFalse {
            trueFalseByID[question.id] = question
        }

        return DeckTestConfiguration(
            mode: incoming.mode,
            multipleChoice: orderedMerge(
                existing: multipleChoice,
                incoming: incoming.multipleChoice,
                valuesByID: multipleChoiceByID
            ),
            trueFalse: orderedMerge(
                existing: trueFalse,
                incoming: incoming.trueFalse,
                valuesByID: trueFalseByID
            )
        )
    }

    func duplicated(remappingCardIDs cardIDMap: [UUID: UUID]) -> Self {
        guard mode != .useFlashcards else { return .useFlashcards }
        return DeckTestConfiguration(
            mode: mode,
            multipleChoice: multipleChoice.compactMap { question in
                guard let sourceCardID = cardIDMap[question.sourceCardID] else { return nil }
                return AuthoredMultipleChoiceQuestion(
                    sourceCardID: sourceCardID,
                    prompt: question.prompt,
                    choices: question.choices,
                    correctChoiceIndex: question.correctChoiceIndex
                )
            },
            trueFalse: trueFalse.compactMap { question in
                guard let sourceCardID = cardIDMap[question.sourceCardID] else { return nil }
                return AuthoredTrueFalseQuestion(
                    sourceCardID: sourceCardID,
                    statement: question.statement,
                    correctAnswer: question.correctAnswer
                )
            }
        )
    }

    private func orderedMerge<Value: Identifiable>(
        existing: [Value],
        incoming: [Value],
        valuesByID: [Value.ID: Value]
    ) -> [Value] where Value.ID: Hashable {
        var orderedIDs = existing.map(\.id)
        let existingIDs = Set(orderedIDs)
        orderedIDs.append(contentsOf: incoming.map(\.id).filter { !existingIDs.contains($0) })
        return orderedIDs.compactMap { valuesByID[$0] }
    }
}

enum AuthoredTestValidationError: Error, Equatable, Sendable {
    case emptyPrompt
    case invalidChoiceCount
    case duplicateChoices
    case invalidCorrectChoice
    case unknownSourceCard(UUID)
    case duplicateQuestionID(UUID)
}

enum AuthoredTestText {
    static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalize(_ value: String) -> String {
        let locale = Locale(identifier: "fr_FR")
        return clean(value)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: locale
            )
            .lowercased(with: locale)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
