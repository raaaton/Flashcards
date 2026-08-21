import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID
    var name: String
    var createdAt: Date
    var iconName: String = "folder.fill"
    var colorHex: String = "5856D6"
    var sortOrder: Int = Int.max

    @Relationship(deleteRule: .cascade, inverse: \Deck.folder)
    var decks: [Deck]

    init(
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "5856D6",
        sortOrder: Int = Int.max
    ) {
        id = UUID()
        self.name = name
        createdAt = .now
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        decks = []
    }
}
