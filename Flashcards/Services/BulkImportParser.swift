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
