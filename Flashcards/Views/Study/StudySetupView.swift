import SwiftData
import SwiftUI

struct StudySetupView: View {
    @Environment(\.modelContext) private var modelContext

    let deck: Deck

    @State private var direction = AppPreferences.studyDirection
    @State private var shuffle = AppPreferences.studyShuffle
    @State private var starredOnly = AppPreferences.studyStarredOnly
    @State private var sessionSize = SessionSize.all
    @State private var showingSession = false
    @State private var confirmingReset = false
    @State private var confirmingNewSeries = false
    @State private var launchedSession: ActiveStudySessionSnapshot?

    private var eligibleCount: Int {
        eligibleCards.count
    }

    private var eligibleCards: [Card] {
        deck.cards.filter { card in
            !card.mastered && (!starredOnly || card.isStarred)
        }
    }

    private var hasStarredCards: Bool {
        deck.cards.contains(where: \.isStarred)
    }

    private var canStart: Bool {
        if resumableSession != nil { return true }
        return !deck.cards.isEmpty && (!starredOnly || hasStarredCards)
    }

    private var nextSessionNumber: Int {
        resumableSession?.sessionNumber ?? deck.completedStudySessions + 1
    }

    private var resumableSession: ActiveStudySessionSnapshot? {
        guard let data = deck.activeStudySessionData,
                let snapshot = StudySessionPersistence.decode(data, deckID: deck.id),
                snapshot.state.currentIndex > 0 else {
            return nil
        }
        let deckCardIDs = Set(deck.cards.map(\.id))
        let remainingIDs = snapshot.state.items
            .dropFirst(snapshot.state.currentIndex)
            .map(\.id)
        guard remainingIDs.allSatisfy(deckCardIDs.contains) else { return nil }
        return snapshot
    }

    private var masteredCount: Int {
        deck.cards.count(where: \.mastered)
    }

    private var accent: Color { Theme.deckAccent(for: deck) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Label(
                        L10n.format("study.session.number", Int64(nextSessionNumber)),
                        systemImage: "rectangle.stack.fill"
                    )
                        .font(.title2.bold())
                        .foregroundStyle(accent)
                        .accessibilityAddTraits(.isHeader)
                    if resumableSession != nil {
                        Text("study.session.in_progress")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sens") {
                    LabeledContent("Sens") {
                        StudyDirectionMenu(selection: $direction, accent: accent)
                            .onChange(of: direction) { _, newValue in
                                guard resumableSession == nil else { return }
                                AppPreferences.studyDirection = newValue
                            }
                    }
                }
                .disabled(resumableSession != nil)

                Section("Options") {
                    Toggle("Mélanger", isOn: $shuffle)
                        .onChange(of: shuffle) { _, newValue in
                            guard resumableSession == nil else { return }
                            AppPreferences.studyShuffle = newValue
                        }

                    Toggle("study.starred_only", isOn: $starredOnly)
                        .onChange(of: starredOnly) { _, newValue in
                            guard resumableSession == nil else { return }
                            AppPreferences.studyStarredOnly = newValue
                        }

                    Picker("session.size.title", selection: $sessionSize) {
                        ForEach(SessionSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .disabled(resumableSession != nil)

                if starredOnly && !hasStarredCards && resumableSession == nil {
                    Section {
                        Label("study.no_starred", systemImage: "star.slash")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    DeckProgressBar(
                        deckName: deck.name,
                        masteredCount: masteredCount,
                        totalCount: deck.cards.count,
                        accent: accent
                    )
                }

                Section {
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Label("Réinitialiser la progression", systemImage: "arrow.counterclockwise")
                    }
                    .destructiveActionColor()
                    .disabled(
                        deck.completedStudySessions == 0
                            && deck.cards.allSatisfy { !$0.mastered }
                            && resumableSession == nil
                    )
                }
            }

            PrimaryStartButton(
                title: resumableSession == nil ? "common.start" : "study.resume",
                isEnabled: canStart,
                accent: accent
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
        .tint(accent)
        .navigationDestination(isPresented: $showingSession) {
            if let launchedSession {
                StudyView(deck: deck, snapshot: launchedSession)
            }
        }
        .alert("Réinitialiser la progression ?", isPresented: $confirmingReset) {
            Button("Réinitialiser", role: .destructive) { resetProgress() }
            Button("Annuler", role: .cancel) {}
                .tint(.gray)
                .foregroundStyle(.secondary)
        } message: {
            Text("Toutes les cartes de ce deck redeviendront non maîtrisées.")
        }
        .alert("study.new_series.title", isPresented: $confirmingNewSeries) {
            Button("Continuer", role: .destructive) {
                LibraryActions.resetStudyProgress(for: deck, in: modelContext)
                startNewSession()
            }
            .destructiveActionColor()
            Button("Annuler", role: .cancel) {}
                .tint(.gray)
        } message: {
            Text("study.new_series.message")
        }
        .onAppear {
            if let resumableSession {
                direction = resumableSession.state.direction
                shuffle = resumableSession.state.shuffle
                starredOnly = resumableSession.state.starredOnly ?? false
                sessionSize = resumableSession.state.sessionSize ?? .all
            }
        }
    }

    private func resetProgress() {
        LibraryActions.resetStudyProgress(for: deck, in: modelContext)
    }

    private func startNewSession() {
        var selectedCards = eligibleCards.sorted { $0.position < $1.position }
        if shuffle { selectedCards.shuffle() }
        if let limit = sessionSize.limit {
            selectedCards = Array(selectedCards.prefix(limit))
        }
        let cards = selectedCards
            .map { StudyCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition) }
        guard !cards.isEmpty else { return }

        let snapshot = ActiveStudySessionSnapshot(
            deckID: deck.id,
            sessionNumber: deck.completedStudySessions + 1,
            state: StudySessionState(
                cards: cards,
                direction: direction,
                shuffle: shuffle,
                sessionSize: sessionSize,
                starredOnly: starredOnly
            )
        )
        launchedSession = snapshot
        showingSession = true
    }

    private func resume(_ snapshot: ActiveStudySessionSnapshot) {
        deck.lastStudyActivityAt = .now
        try? modelContext.save()
        launchedSession = snapshot
        showingSession = true
    }
}
