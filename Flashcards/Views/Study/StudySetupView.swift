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
    @State private var launchedSession: ActiveStudySessionSnapshot?

    private var eligibleCount: Int {
        deck.cards.count(where: { !$0.mastered })
    }

    private var nextSessionNumber: Int {
        resumableSession?.sessionNumber ?? deck.completedStudySessions + 1
    }

    private var remainingCount: Int {
        resumableSession?.state.remainingCards ?? eligibleCount
    }

    private var resumableSession: ActiveStudySessionSnapshot? {
        guard let data = deck.activeStudySessionData,
              let snapshot = StudySessionPersistence.decode(data, deckID: deck.id) else {
            return nil
        }
        let deckCardIDs = Set(deck.cards.map(\.id))
        let remainingIDs = snapshot.state.items
            .dropFirst(snapshot.state.currentIndex)
            .map(\.id)
        guard remainingIDs.allSatisfy(deckCardIDs.contains) else { return nil }
        return snapshot
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
                    if resumableSession != nil {
                        Text("study.session.in_progress")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sens") {
                    LabeledContent("Sens") {
                        StudyDirectionMenu(selection: $direction)
                    }
                }
                .disabled(resumableSession != nil)

                Section("Options") {
                    Toggle("Mélanger", isOn: $shuffle)
                }
                .disabled(resumableSession != nil)

                Section("Progression") {
                    Text(L10n.format("study.cards_remaining", Int64(remainingCount)))
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
                            && resumableSession == nil
                    )
                }
            }

            PrimaryStartButton(
                title: resumableSession == nil ? "common.start" : "study.resume",
                isEnabled: !deck.cards.isEmpty
            ) {
                if let resumableSession {
                    resume(resumableSession)
                } else if eligibleCount == 0 {
                    confirmingNewSeries = true
                } else {
                    startNewSession()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationTitle("Flashcards")
        .navigationDestination(isPresented: $showingSession) {
            if let launchedSession {
                StudyView(deck: deck, snapshot: launchedSession)
            }
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
                startNewSession()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("study.new_series.message")
        }
        .onAppear {
            if let resumableSession {
                direction = resumableSession.state.direction
                shuffle = resumableSession.state.shuffle
            }
        }
    }

    private func resetProgress() {
        LibraryActions.resetStudyProgress(for: deck, in: modelContext)
    }

    private func startNewSession() {
        let cards = deck.cards
            .filter { !$0.mastered }
            .sorted { $0.position < $1.position }
            .map { StudyCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition) }
        guard !cards.isEmpty else { return }

        let snapshot = ActiveStudySessionSnapshot(
            deckID: deck.id,
            sessionNumber: deck.completedStudySessions + 1,
            state: StudySessionState(cards: cards, direction: direction, shuffle: shuffle)
        )
        guard let data = try? StudySessionPersistence.encode(snapshot) else { return }
        deck.activeStudySessionData = data
        deck.updatedAt = .now
        try? modelContext.save()
        launchedSession = snapshot
        showingSession = true
    }

    private func resume(_ snapshot: ActiveStudySessionSnapshot) {
        launchedSession = snapshot
        showingSession = true
    }
}
