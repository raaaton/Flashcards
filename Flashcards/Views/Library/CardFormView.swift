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

    private var accent: Color {
        Theme.deckAccent(for: deck)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardEditorSurface(
                        term: $term,
                        definition: $definition,
                        accent: accent
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: 12,
                            leading: 0,
                            bottom: 12,
                            trailing: 0
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
                        .tint(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    CircularSaveButton(
                        accent: accent,
                        isEnabled: !cleanTerm.isEmpty
                            && !cleanDefinition.isEmpty
                    ) {
                        save()
                    }
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
