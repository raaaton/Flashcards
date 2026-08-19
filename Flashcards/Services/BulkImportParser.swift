import Foundation

enum TermDefinitionDelimiterOption: String, CaseIterable, Identifiable, Sendable {
    case tab
    case comma
    case semicolon
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .tab: "Tabulation"
        case .comma: "Virgule"
        case .semicolon: "Point-virgule"
        case .custom: "Personnalisé"
        }
    }

    func resolved(customValue: String) -> String {
        switch self {
        case .tab: "\t"
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
        case .newline: "Nouvelle ligne"
        case .semicolon: "Point-virgule"
        case .custom: "Personnalisé"
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
                        reason: "Délimiteur terme/définition absent"
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
                        reason: term.isEmpty ? "Terme vide" : "Définition vide"
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
