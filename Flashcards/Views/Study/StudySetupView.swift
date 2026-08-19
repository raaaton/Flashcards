import SwiftUI

struct StudySetupView: View {
    let deck: Deck

    @State private var direction = StudyDirection.termToDefinition
    @State private var includeMastered: Bool

    init(deck: Deck) {
        self.deck = deck
        let hasUnmasteredCards = deck.cards.contains { !$0.mastered }
        _includeMastered = State(initialValue: !deck.cards.isEmpty && !hasUnmasteredCards)
    }

    private var eligibleCount: Int {
        includeMastered ? deck.cards.count : deck.cards.count(where: { !$0.mastered })
    }

    var body: some View {
        Form {
            Section("Sens d’étude") {
                Picker("Sens", selection: $direction) {
                    ForEach(StudyDirection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Cartes") {
                Toggle("Inclure les cartes maîtrisées", isOn: $includeMastered)
                LabeledContent("Cette session", value: "\(eligibleCount) carte\(eligibleCount > 1 ? "s" : "")")
            }

            Section {
                NavigationLink {
                    StudyView(
                        deck: deck,
                        direction: direction,
                        includeMastered: includeMastered
                    )
                } label: {
                    Label("Commencer la session", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(eligibleCount == 0)
            } footer: {
                if eligibleCount == 0 {
                    Text("Toutes les cartes sont déjà maîtrisées. Activez leur inclusion pour les revoir.")
                }
            }
        }
        .navigationTitle("Flashcards")
    }
}
