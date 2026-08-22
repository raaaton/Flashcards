import SwiftData
import SwiftUI

struct CardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck
    let card: Card?
    @State private var term: String
    @State private var definition: String
    @State private var showingDuplicateChoice = false

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

    private var duplicateKind: BulkDuplicateKind? {
        guard !cleanTerm.isEmpty, !cleanDefinition.isEmpty else { return nil }

        let candidate = ParsedCard(
            recordIndex: 0,
            term: cleanTerm,
            definition: cleanDefinition
        )
        let existingCards = deck.cards
            .filter { $0.id != card?.id }
            .map { ($0.term, $0.definition) }

        return BulkDuplicateDetector.analyze(
            candidates: [candidate],
            existingCards: existingCards
        )
        .kind(for: candidate.recordIndex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardEditorSurface(
                        term: $term,
                        definition: $definition
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

                if let duplicateKind {
                    Section {
                        duplicateWarning(for: duplicateKind)
                    }
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
                        prepareSave()
                    }
                }
            }
            .alert("Doublon détecté", isPresented: $showingDuplicateChoice) {
                Button(card == nil ? "Ajouter quand même" : "Enregistrer quand même") {
                    persistCard()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text(duplicateAlertMessage)
            }
        }
    }

    @ViewBuilder
    private func duplicateWarning(for kind: BulkDuplicateKind) -> some View {
        switch kind {
        case .exact:
            Label(
                "Une carte identique existe déjà dans ce deck.",
                systemImage: "exclamationmark.octagon.fill"
            )
            .foregroundStyle(.red)
        case .possible:
            Label(
                "Une carte avec le même terme existe déjà dans ce deck.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        }
    }

    private var duplicateAlertMessage: String {
        switch duplicateKind {
        case .exact:
            "Une carte avec le même terme et la même définition existe déjà dans ce deck."
        case .possible:
            "Une carte avec le même terme mais une définition différente existe déjà dans ce deck."
        case nil:
            "Cette carte ressemble à une carte déjà présente dans ce deck."
        }
    }

    private func prepareSave() {
        guard !cleanTerm.isEmpty, !cleanDefinition.isEmpty else { return }

        if duplicateKind != nil {
            showingDuplicateChoice = true
        } else {
            persistCard()
        }
    }

    private func persistCard() {
        if let card {
            card.term = cleanTerm
            card.definition = cleanDefinition
        } else {
            let nextPosition = (deck.cards.map(\.position).max() ?? -1) + 1
            let newCard = Card(
                term: cleanTerm,
                definition: cleanDefinition,
                position: nextPosition
            )
            newCard.deck = deck
            modelContext.insert(newCard)
        }
        deck.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
