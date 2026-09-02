import Foundation
import SwiftData

@Model
final class Card {
    var id: UUID
    var term: String
    var definition: String
    var position: Int
    var mastered: Bool
    var testMastered: Bool = false
    var timesStudied: Int
    var timesCorrect: Int
    var isStarred: Bool = false
    var deck: Deck?

    init(term: String, definition: String, position: Int) {
        id = UUID()
        self.term = term
        self.definition = definition
        self.position = position
        mastered = false
        testMastered = false
        timesStudied = 0
        timesCorrect = 0
        isStarred = false
    }
}
