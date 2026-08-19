import SwiftData
import SwiftUI

struct StudySetupView: View {
    @Environment(\.modelContext) private var modelContext

    let deck: Deck

    @State private var direction = StudyDirection.termToDefinition
    @State private var shuffle = true
    @State private var showingSession = false
    @State private var confirmingReset = false
    @State private var confirmingNewSeries = false
    @State private var activeSessionNumber: Int

    init(deck: Deck) {
        self.deck = deck
        _activeSessionNumber = State(initialValue: deck.completedStudySessions + 1)
    }

    private var eligibleCount: Int {
        deck.cards.count(where: { !$0.mastered })
    }

    private var nextSessionNumber: Int {
        deck.completedStudySessions + 1
    }

    private var masteredPercentage: Int {
        guard !deck.cards.isEmpty else { return 0 }
        let mastered = deck.cards.count(where: \.mastered)
        return Int((Double(mastered) / Double(deck.cards.count) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Label(
                        L10n.format("study.session.number", Int64(nextSessionNumber)),
                        systemImage: "rectangle.stack.fill"
                    )
                        .font(.title2.bold())
                        .foregroundStyle(Theme.accent)
                        .accessibilityAddTraits(.isHeader)
                }

                Section("Sens") {
                    LabeledContent("Sens") {
                        StudyDirectionMenu(selection: $direction)
                    }
                }

                Section("Options") {
                    Toggle("Mélanger", isOn: $shuffle)
                }

                Section("Progression") {
                    Text(L10n.format("study.cards_remaining", Int64(eligibleCount)))
                    Text(L10n.format("study.mastered.percent", Int64(masteredPercentage)))
                }

                Section {
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Label("Réinitialiser la progression", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                    }
                    .disabled(
                        deck.completedStudySessions == 0
                            && deck.cards.allSatisfy { !$0.mastered }
                    )
                }
            }

            PrimaryStartButton(isEnabled: !deck.cards.isEmpty) {
                if eligibleCount == 0 {
                    confirmingNewSeries = true
                } else {
                    startSession()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationTitle("Flashcards")
        .navigationDestination(isPresented: $showingSession) {
            StudyView(
                deck: deck,
                direction: direction,
                shuffle: shuffle,
                sessionNumber: activeSessionNumber
            )
        }
        .alert("Réinitialiser la progression ?", isPresented: $confirmingReset) {
            Button("Réinitialiser", role: .destructive) { resetProgress() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les cartes de ce deck redeviendront non maîtrisées.")
        }
        .alert("study.new_series.title", isPresented: $confirmingNewSeries) {
            Button("Continuer") {
                LibraryActions.resetStudyProgress(for: deck, in: modelContext)
                startSession()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("study.new_series.message")
        }
    }

    private func resetProgress() {
        LibraryActions.resetStudyProgress(for: deck, in: modelContext)
        activeSessionNumber = 1
    }

    private func startSession() {
        activeSessionNumber = deck.completedStudySessions + 1
        deck.completedStudySessions = activeSessionNumber
        deck.updatedAt = .now
        try? modelContext.save()
        showingSession = true
    }
}
