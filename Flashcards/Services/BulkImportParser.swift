import Foundation

enum TermDefinitionDelimiterOption: String, CaseIterable, Identifiable, Sendable {
    case colon
    case comma
    case semicolon
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .colon: L10n.text("import.delimiter.colon")
        case .comma: L10n.text("import.delimiter.comma")
        case .semicolon: L10n.text("import.delimiter.semicolon")
        case .custom: L10n.text("import.delimiter.custom")
        }
    }

    func resolved(customValue: String) -> String {
        switch self {
        case .colon: ":"
        case .comma: ","
        case .semicolon: ";"
        case .custom: customValue
        }
    }
}

enum CardDelimiterOption: String, CaseIterable, Identifiable, Sendable {
    case newline
    case semicolon
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .newline: L10n.text("import.delimiter.newline")
        case .semicolon: L10n.text("import.delimiter.semicolon")
        case .custom: L10n.text("import.delimiter.custom")
        }
    }

    func resolved(customValue: String) -> String {
        switch self {
        case .newline: "\n"
        case .semicolon: ";"
        case .custom: customValue
        }
    }
}

struct BulkImportInput: Hashable, Sendable {
    var text: String
    var termDelimiter: String
    var cardDelimiter: String
}

struct ParsedCard: Identifiable, Equatable, Sendable {
    let recordIndex: Int
    let term: String
    let definition: String

    var id: Int { recordIndex }
}

struct InvalidRecord: Identifiable, Equatable, Sendable {
    let recordIndex: Int
    let content: String
    let reason: String

    var id: Int { recordIndex }
}

struct BulkImportResult: Equatable, Sendable {
    var cards: [ParsedCard]
    var invalidRecords: [InvalidRecord]
    var ignoredEmptyRecords: Int

    static let empty = BulkImportResult(cards: [], invalidRecords: [], ignoredEmptyRecords: 0)
}

enum BulkDuplicateKind: String, Sendable {
    case exact
    case possible
}

struct BulkDuplicateMatch: Identifiable, Equatable, Sendable {
    let recordIndex: Int
    let kind: BulkDuplicateKind

    var id: Int { recordIndex }
}

struct BulkDuplicateAnalysis: Equatable, Sendable {
    var matches: [BulkDuplicateMatch]

    var exactRecordIndexes: Set<Int> {
        Set(matches.lazy.filter { $0.kind == .exact }.map(\.recordIndex))
    }

    var exactCount: Int { matches.count { $0.kind == .exact } }
    var possibleCount: Int { matches.count { $0.kind == .possible } }

    func kind(for recordIndex: Int) -> BulkDuplicateKind? {
        matches.first { $0.recordIndex == recordIndex }?.kind
    }
}

enum BulkDuplicateDetector {
    /// Compares each candidate with the destination and with every earlier candidate.
    /// Exact duplicates share a normalized term and definition. A matching term with a
    /// different definition is reported as a possible duplicate and is never skipped.
    static func analyze(
        candidates: [ParsedCard],
        existingCards: [(term: String, definition: String)]
    ) -> BulkDuplicateAnalysis {
        var knownDefinitionsByTerm: [String: Set<String>] = [:]
        for card in existingCards {
            let term = normalize(card.term)
            let definition = normalize(card.definition)
            guard !term.isEmpty, !definition.isEmpty else { continue }
            knownDefinitionsByTerm[term, default: []].insert(definition)
        }

        var matches: [BulkDuplicateMatch] = []
        for card in candidates {
            let term = normalize(card.term)
            let definition = normalize(card.definition)
            let knownDefinitions = knownDefinitionsByTerm[term, default: []]

            if knownDefinitions.contains(definition) {
                matches.append(
                    BulkDuplicateMatch(recordIndex: card.recordIndex, kind: .exact)
                )
            } else if !knownDefinitions.isEmpty {
                matches.append(
                    BulkDuplicateMatch(recordIndex: card.recordIndex, kind: .possible)
                )
            }

            knownDefinitionsByTerm[term, default: []].insert(definition)
        }
        return BulkDuplicateAnalysis(matches: matches)
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

enum BulkImportParser {
    static func parse(_ input: BulkImportInput) -> BulkImportResult {
        guard !input.termDelimiter.isEmpty, !input.cardDelimiter.isEmpty else {
            return .empty
        }

        var cards: [ParsedCard] = []
        var invalidRecords: [InvalidRecord] = []
        var ignoredEmptyRecords = 0
        let records = input.text.components(separatedBy: input.cardDelimiter)

        for (index, rawRecord) in records.enumerated() {
            let record = rawRecord.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !record.isEmpty else {
                ignoredEmptyRecords += 1
                continue
            }

            guard let separatorRange = record.range(of: input.termDelimiter) else {
                invalidRecords.append(
                    InvalidRecord(
                        recordIndex: index,
                        content: record,
                        reason: L10n.text("import.error.missing_term_delimiter")
                    )
                )
                continue
            }

            let term = String(record[..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let definition = String(record[separatorRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !term.isEmpty, !definition.isEmpty else {
                invalidRecords.append(
                    InvalidRecord(
                        recordIndex: index,
                        content: record,
                        reason: term.isEmpty
                            ? L10n.text("import.error.empty_term")
                            : L10n.text("import.error.empty_definition")
                    )
                )
                continue
            }

            cards.append(ParsedCard(recordIndex: index, term: term, definition: definition))
        }

        return BulkImportResult(
            cards: cards,
            invalidRecords: invalidRecords,
            ignoredEmptyRecords: ignoredEmptyRecords
        )
    }
}

enum ExternalAIProvider: String, CaseIterable, Identifiable, Sendable {
    case chatGPT
    case claude
    case gemini

    var id: Self { self }

    var displayName: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .claude: "Claude"
        case .gemini: "Gemini"
        }
    }

    var systemImage: String {
        switch self {
        case .chatGPT: "sparkles"
        case .claude: "text.bubble.fill"
        case .gemini: "diamond.fill"
        }
    }

    var isRecommended: Bool { self == .chatGPT }

    var launchURL: URL {
        switch self {
        case .chatGPT:
            URL(string: "https://chatgpt.com/")!
        case .claude:
            URL(string: "https://claude.ai/")!
        case .gemini:
            URL(string: "https://gemini.google.com/")!
        }
    }

    // These consumer chat routes intentionally do not rely on undocumented prompt-prefill parameters.
    func launchURL(for _: String) -> URL {
        launchURL
    }
}

enum ExternalAIFlashcardPromptBuilder {
    static func makePrompt(deckName: String, appName: String = "Flashcards") -> String {
        let cleanDeckName = deckName
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        You are preparing flashcards for \(appName), an iOS study app. The deck is named "\(cleanDeckName)".

        The user will attach notes, images, slides, PDFs, or other study documents with this message. Use those attachments as the source of truth. Create concise, accurate, useful flashcards for revision. Cover the important ideas without padding the set with redundant or trivial items. Keep each term focused and each definition short enough to review quickly. Preserve the language of the source material unless the user clearly asks otherwise.

        Return machine-readable JSON using exactly this shape:
        {
          "flashcards": [
            {
              "term": "A concise question, concept, or cue",
              "definition": "A concise answer or explanation"
            }
          ]
        }

        Requirements:
        - Return at least one flashcard when the source contains useful study material.
        - Every item must contain a non-empty "term" and "definition" string.
        - Do not add extra JSON keys.
        - Keep line breaks and punctuation inside JSON strings properly escaped.
        - Do not use a colon-delimited plain-text format.

        In your final answer, first write exactly this guidance sentence:
        Your flashcards are ready for \(appName). Copy the JSON block below, then return to \(appName).

        Then output one fenced ```json block containing only the JSON object. Do not add commentary after the JSON block.
        """
    }
}

enum ExternalAIFlashcardParserError: Error, Equatable, Sendable {
    case invalidJSON
    case emptyResult
    case incompleteRecord(Int)
}

private struct ExternalAIFlashcardValue: Decodable {
    let term: String
    let definition: String
}

private struct ExternalAIFlashcardEnvelope: Decodable {
    let flashcards: [ExternalAIFlashcardValue]
}

enum ExternalAIFlashcardParser {
    static func parse(_ text: String) throws -> [ParsedCard] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ExternalAIFlashcardParserError.invalidJSON
        }

        for candidate in jsonCandidates(from: trimmed) {
            guard let values = decode(candidate) else { continue }
            return try validate(values)
        }

        throw ExternalAIFlashcardParserError.invalidJSON
    }

    private static func decode(_ candidate: String) -> [ExternalAIFlashcardValue]? {
        guard let data = candidate.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(ExternalAIFlashcardEnvelope.self, from: data) {
            return envelope.flashcards
        }

        return try? decoder.decode([ExternalAIFlashcardValue].self, from: data)
    }

    private static func validate(_ values: [ExternalAIFlashcardValue]) throws -> [ParsedCard] {
        guard !values.isEmpty else {
            throw ExternalAIFlashcardParserError.emptyResult
        }

        return try values.enumerated().map { index, value in
            let term = value.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let definition = value.definition.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !term.isEmpty, !definition.isEmpty else {
                throw ExternalAIFlashcardParserError.incompleteRecord(index)
            }

            return ParsedCard(
                recordIndex: index,
                term: term,
                definition: definition
            )
        }
    }

    private static func jsonCandidates(from text: String) -> [String] {
        var candidates: [String] = []

        if let expression = try? NSRegularExpression(
            pattern: "```(?:json)?\\s*([\\s\\S]*?)```",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in expression.matches(in: text, range: range) {
                guard match.numberOfRanges > 1,
                      let candidateRange = Range(match.range(at: 1), in: text) else {
                    continue
                }
                appendUnique(String(text[candidateRange]), to: &candidates)
            }
        }

        appendUnique(text, to: &candidates)

        if let firstBrace = text.firstIndex(of: "{"),
           let lastBrace = text.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            appendUnique(String(text[firstBrace...lastBrace]), to: &candidates)
        }

        if let firstBracket = text.firstIndex(of: "["),
           let lastBracket = text.lastIndex(of: "]"),
           firstBracket <= lastBracket {
            appendUnique(String(text[firstBracket...lastBracket]), to: &candidates)
        }

        return candidates
    }

    private static func appendUnique(_ candidate: String, to candidates: inout [String]) {
        let cleanCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCandidate.isEmpty, !candidates.contains(cleanCandidate) else { return }
        candidates.append(cleanCandidate)
    }
}
