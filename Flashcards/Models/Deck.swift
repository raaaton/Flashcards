import Foundation
import SwiftData

@Model
final class Deck {
    var id: UUID
    var name: String
    var deckDescription: String?
    var createdAt: Date
    var updatedAt: Date
    var completedStudySessions: Int = 0
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Card.deck)
    var cards: [Card]

    init(name: String, folder: Folder? = nil) {
        id = UUID()
        self.name = name
        deckDescription = nil
        createdAt = .now
        updatedAt = .now
        completedStudySessions = 0
        self.folder = folder
        cards = []
    }
}
