import SwiftData
import SwiftUI

struct StudySetupView: View {
    @Environment(\.modelContext) private var modelContext

    let deck: Deck

    @State private var direction = StudyDirection.termToDefinition
    @State private var includeMastered: Bool
    @State private var showingSession = false
    @State private var confirmingReset = false

    init(deck: Deck) {
        self.deck = deck
        let hasUnmasteredCards = deck.cards.contains { !$0.mastered }
        _includeMastered = State(initialValue: !deck.cards.isEmpty && !hasUnmasteredCards)
    }

    private var eligibleCount: Int {
        includeMastered ? deck.cards.count : deck.cards.count(where: { !$0.mastered })
    }

    private var nextSessionNumber: Int {
        deck.completedStudySessions + 1
    }

    var body: some View {
        Form {
            Section {
                Label("Session \(nextSessionNumber)", systemImage: "rectangle.stack.fill")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.accent)
                    .accessibilityAddTraits(.isHeader)
            }

            Section("Sens") {
                Picker("Sens", selection: $direction) {
                    ForEach(StudyDirection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
            }

            Section("Cartes") {
                Toggle("Inclure les cartes maîtrisées", isOn: $includeMastered)
                LabeledContent(
                    "Cette session",
                    value: "\(eligibleCount) carte\(eligibleCount > 1 ? "s" : "")"
                )
            }

            Section {
                Button {
                    showingSession = true
                } label: {
                    Label("Commencer la session", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(eligibleCount == 0)
            } footer: {
                if eligibleCount == 0 {
                    Text("Toutes les cartes sont déjà maîtrisées. Activez leur inclusion pour les revoir.")
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Label("Réinitialiser la progression", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                }
                .disabled(deck.cards.allSatisfy { !$0.mastered })
            }
        }
        .navigationTitle("Flashcards")
        .navigationDestination(isPresented: $showingSession) {
            StudyView(
                deck: deck,
                direction: direction,
                includeMastered: includeMastered,
                sessionNumber: nextSessionNumber
            )
        }
        .alert("Réinitialiser la progression ?", isPresented: $confirmingReset) {
            Button("Réinitialiser", role: .destructive) { resetProgress() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les cartes de ce deck redeviendront non maîtrisées.")
        }
    }

    private func resetProgress() {
        LibraryActions.resetStudyProgress(for: deck, in: modelContext)
        includeMastered = false
    }
}
