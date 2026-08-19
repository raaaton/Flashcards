import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Deck.folder)
    var decks: [Deck]

    init(name: String) {
        id = UUID()
        self.name = name
        createdAt = .now
        decks = []
    }
}
