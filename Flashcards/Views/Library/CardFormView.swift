import SwiftData
import SwiftUI

struct CardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck
    let card: Card?
    @State private var term: String
    @State private var definition: String

    init(deck: Deck, card: Card? = nil) {
        self.deck = deck
        self.card = card
        _term = State(initialValue: card?.term ?? "")
        _definition = State(initialValue: card?.definition ?? "")
    }

    private var cleanTerm: String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanDefinition: String {
        definition.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Terme") {
                    TextField("Terme", text: $term, axis: .vertical)
                        .lineLimit(2...8)
                }
                Section("Définition") {
                    TextField("Définition", text: $definition, axis: .vertical)
                        .lineLimit(3...12)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(
                card == nil
                    ? L10n.text("card.new.title")
                    : L10n.text("card.edit.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(cleanTerm.isEmpty || cleanDefinition.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let card {
            card.term = cleanTerm
            card.definition = cleanDefinition
        } else {
            let nextPosition = (deck.cards.map(\.position).max() ?? -1) + 1
            let newCard = Card(term: cleanTerm, definition: cleanDefinition, position: nextPosition)
            newCard.deck = deck
            modelContext.insert(newCard)
        }
        deck.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
