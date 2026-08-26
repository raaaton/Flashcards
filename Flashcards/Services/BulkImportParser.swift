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

struct ParsedCard: Identifiable, Equatable, Hashable, Sendable {
    let recordIndex: Int
    let term: String
    let definition: String

    var id: Int { recordIndex }
}

struct ExternalAIImportSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let cards: [ParsedCard]

    init(id: UUID = UUID(), cards: [ParsedCard]) {
        self.id = id
        self.cards = cards
    }
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
    case claude
    case chatGPT
    case gemini

    var id: Self { self }

    var displayName: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .claude: "Claude"
        case .gemini: "Gemini"
        }
    }

    var webURL: URL {
        switch self {
        case .chatGPT:
            URL(string: "https://chatgpt.com/")!
        case .claude:
            URL(string: "https://claude.ai/")!
        case .gemini:
            URL(string: "https://gemini.google.com/")!
        }
    }

    var nativeScheme: String {
        switch self {
        case .chatGPT: "chatgpt"
        case .claude: "claude"
        case .gemini: "googlegemini"
        }
    }

    /// Ordered URLs to try for a native handoff. ChatGPT gets conservative prefill
    /// attempts first; Claude and Gemini only use their app-launch schemes because no
    /// consumer-chat prefill route is known to be reliable.
    func nativeLaunchCandidates(for prompt: String) -> [URL] {
        switch self {
        case .chatGPT:
            let hosts = ["chat.openai.com", "chatgpt.com"]
            let queryNames = ["q", "prompt"]
            let prefillCandidates = hosts.flatMap { host in
                queryNames.compactMap { queryName in
                    customURL(host: host, queryName: queryName, prompt: prompt)
                }
            }

            return prefillCandidates + [
                URL(string: "chatgpt://chatgpt.com/")!,
                URL(string: "chatgpt://")!
            ]
        case .claude:
            return [URL(string: "claude://")!]
        case .gemini:
            return [URL(string: "googlegemini://")!]
        }
    }

    private func customURL(host: String, queryName: String, prompt: String) -> URL? {
        var components = URLComponents()
        components.scheme = nativeScheme
        components.host = host
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: queryName, value: prompt)
        ]
        return components.url
    }
}

enum ExternalAIFlashcardPromptBuilder {
    static func makePrompt(deckName: String, appName: String = "Kavi") -> String {
        let cleanDeckName = deckName
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        You are preparing flashcards for \(appName), an iOS study app. The deck is named "\(cleanDeckName)".

        The user will attach notes, images, slides, PDFs, or other study documents with this message. Use those attachments as the source of truth. Preserve the language of the source material unless the user clearly asks otherwise.

        First, inspect the entire source for explicit term-definition pairs and explicit date-event pairs.

        Explicit-pair rules:
        - If the source explicitly defines a term or concept, create a flashcard for EVERY distinct explicit definition found.
          - "term" must be the term or concept being defined.
          - "definition" must faithfully contain the definition given by the source.
        - If the source explicitly associates a date or year with an event, create a flashcard for EVERY distinct explicit date-event pair found.
          - "term" must be the date or year as presented in the source.
          - "definition" must be the event associated with that date.
        - This applies to definitions and dates found anywhere in the source, including glossaries, vocabulary lists, timelines, tables, callouts, slides, and normal prose.
        - Do not omit an explicit definition or date-event pair because it seems minor, obvious, or less important.
        - Only remove exact duplicate pairs when the same information is repeated unchanged.
        - If multiple cards have the same term but different definitions, keep all of them. Do not merge or discard them as duplicates.
        - Do not invent definitions or date-event relationships that are not clearly supported by the source.
        - Every explicit term-definition pair MUST be represented as a direct term → definition card: use the term itself as "term" and its corresponding definition as "definition". Never rewrite these cards as questions.
        - Every explicit date-event pair MUST be represented as a direct date → event card: use the date or year itself as "term" and its associated event as "definition". Never rewrite these cards as questions.

        Then handle the rest of the material:
        - If the source contains useful study material beyond those explicit definitions and dates, also create concise flashcards covering its important ideas, relationships, processes, facts, and concepts.
        - Keep these additional cards focused and useful for revision without padding the set with redundant or trivial items.
        - Avoid creating an additional reworded card when an explicit term-definition or date-event card already covers the same information.

        If the source contains no explicit definitions and no explicit date-event pairs, simply create concise, accurate, useful flashcards covering the important ideas as usual.

        Return machine-readable JSON using exactly this shape (the angle-bracket values below describe the schema; replace them with actual JSON strings):
        {
          "flashcards": [
            {
              "term": <concise question, concept, term, or date>,
              "definition": <concise answer, definition, explanation, or event>
            }
          ]
        }

        Requirements:
        - Return at least one flashcard when the source contains useful study material.
        - Every item must contain a non-empty "term" and "definition" string.
        - Do not add extra JSON keys.
        - Keep line breaks and punctuation inside JSON strings properly escaped.
        - Do not use a colon-delimited plain-text format.
        - Before finishing, verify that every explicit term-definition pair and every explicit date-event pair from the source has been included.

        In your final answer, first write exactly this guidance sentence:
        Your flashcards are ready for \(appName). Wait until the generation is fully complete, then copy the JSON block below and return to \(appName).

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
