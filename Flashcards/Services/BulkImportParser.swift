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
