import Foundation

@main
enum BulkImportParserSmoke {
    static func main() {
        let fiftyLines = (1...60)
            .map { "Terme \($0): Définition \($0)" }
            .joined(separator: "\n")
        let colonResult = BulkImportParser.parse(
            BulkImportInput(text: fiftyLines, termDelimiter: ":", cardDelimiter: "\n")
        )
        precondition(colonResult.cards.count == 60)
        precondition(colonResult.invalidRecords.isEmpty)

        let mixed = " Alpha , Première définition ;invalide; Beta , Seconde, avec virgule ; , vide"
        let commaResult = BulkImportParser.parse(
            BulkImportInput(text: mixed, termDelimiter: ",", cardDelimiter: ";")
        )
        precondition(commaResult.cards.count == 2)
        precondition(commaResult.cards[0].term == "Alpha")
        precondition(commaResult.cards[1].definition == "Seconde, avec virgule")
        precondition(commaResult.invalidRecords.count == 2)

        let customResult = BulkImportParser.parse(
            BulkImportInput(text: "un => one|||deux => two", termDelimiter: "=>", cardDelimiter: "|||")
        )
        precondition(customResult.cards.map(\.term) == ["un", "deux"])

        let blankResult = BulkImportParser.parse(
            BulkImportInput(text: "\n\n", termDelimiter: "\t", cardDelimiter: "\n")
        )
        precondition(blankResult.cards.isEmpty)
        precondition(blankResult.ignoredEmptyRecords == 3)

        print("BulkImportParser smoke tests passed")
    }
}
