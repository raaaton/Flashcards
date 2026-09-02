import SwiftData
import SwiftUI

struct TestSetupView: View {
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var selectedTypes = Set(TestQuestionType.allCases)
    @State private var direction = AppPreferences.studyDirection
    @State private var shuffle = AppPreferences.studyShuffle
    @State private var starredOnly = AppPreferences.studyStarredOnly
    @State private var sessionSize = SessionSize.all
    @State private var showingTest = false
    @State private var confirmingReset = false
    @State private var confirmingNewSeries = false
    @State private var launchedSession: ActiveTestSessionSnapshot?

    private var eligibleCards: [Card] {
        deck.cards.filter { card in
            !card.testMastered && (!starredOnly || card.isStarred)
        }
    }

    private var selectableCards: [Card] {
        deck.cards.filter { !starredOnly || $0.isStarred }
    }

    private var configuration: DeckTestConfiguration {
        deck.testConfiguration
    }

    private var eligibleSnapshots: [TestCardSnapshot] {
        snapshots(for: eligibleCards)
    }

    private var selectableSnapshots: [TestCardSnapshot] {
        snapshots(for: selectableCards)
    }

    private var availability: AuthoredTestAvailability {
        AuthoredTestQuestionFactory.availability(
            cards: eligibleSnapshots,
            configuration: configuration
        )
    }

    private var selectableAvailability: AuthoredTestAvailability {
        AuthoredTestQuestionFactory.availability(
            cards: selectableSnapshots,
            configuration: configuration
        )
    }

    private var availableCount: Int {
        configuration.mode == .useFlashcards
            ? eligibleCards.count
            : availability.total(for: selectedTypes)
    }

    private var selectableCount: Int {
        configuration.mode == .useFlashcards
            ? selectableCards.count
            : selectableAvailability.total(for: selectedTypes)
    }

    private var effectiveCount: Int {
        if let resumableSession {
            return resumableSession.state.questions.count
        }
        return min(sessionSize.limit ?? availableCount, availableCount)
    }

    private var hasStarredCards: Bool {
        deck.cards.contains(where: \.isStarred)
    }

    private var canStart: Bool {
        if resumableSession != nil { return true }
        return !selectedTypes.isEmpty && (effectiveCount > 0 || canStartNewSeries)
    }

    private var canStartNewSeries: Bool {
        availableCount == 0 && selectableCount > 0
    }

    private var nextSessionNumber: Int {
        resumableSession?.sessionNumber ?? deck.completedTestSessions + 1
    }

    private var resumableSession: ActiveTestSessionSnapshot? {
        guard let data = deck.activeTestSessionData,
              let snapshot = TestSessionPersistence.decode(data, deckID: deck.id) else {
            return nil
        }
        let deckCardIDs = Set(deck.cards.map(\.id))
        guard snapshot.state.questions.allSatisfy({ deckCardIDs.contains($0.cardID) }) else {
            return nil
        }
        return snapshot
    }

    private var testMasteredCount: Int {
        deck.cards.count(where: \.testMastered)
    }

    private var accent: Color { Theme.deckAccent(for: deck) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Label(
                        L10n.format("study.session.number", Int64(nextSessionNumber)),
                        systemImage: "checklist"
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

                Section {
                    ForEach(TestQuestionType.allCases) { type in
                        HStack {
                            Toggle(type.title, isOn: typeBinding(type))
                                .disabled(resumableSession != nil || !isTypeAvailable(type))

                            if configuration.mode != .useFlashcards {
                                Text("\(availability.count(for: type))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                } header: {
                    Text("Types de questions")
                } footer: {
                    if selectedTypes.isEmpty {
                        Text("Sélectionnez au moins un type de question.")
                    }
                }

                if configuration.mode == .useFlashcards || selectedTypes.contains(.written) {
                    Section {
                        LabeledContent("Sens") {
                            StudyDirectionMenu(selection: $direction, accent: accent)
                                .onChange(of: direction) { _, newValue in
                                    guard resumableSession == nil else { return }
                                    AppPreferences.studyDirection = newValue
                                }
                        }
                    } header: {
                        Text("Sens")
                    } footer: {
                        if configuration.mode != .useFlashcards {
                            Text("test.authored.direction_note")
                        }
                    }
                    .disabled(resumableSession != nil)
                }

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
                            normalizeSelectedTypes()
                        }
                }
                .disabled(resumableSession != nil)

                Section("session.size.title") {
                    Picker("session.size.title", selection: $sessionSize) {
                        ForEach(SessionSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Test prévu", value: L10n.questions(effectiveCount))
                }
                .disabled(resumableSession != nil)

                if starredOnly && !hasStarredCards && resumableSession == nil {
                    Section {
                        Label("study.no_starred", systemImage: "star.slash")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TestProgressBar(
                        deckName: deck.name,
                        masteredCount: testMasteredCount,
                        totalCount: deck.cards.count,
                        accent: accent
                    )
                }

                Section {
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Label("test.progress.reset.action", systemImage: "arrow.counterclockwise")
                    }
                    .destructiveActionColor()
                    .disabled(
                        deck.completedTestSessions == 0
                            && deck.cards.allSatisfy { !$0.testMastered }
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
                } else if canStartNewSeries {
                    confirmingNewSeries = true
                } else {
                    startNewSession()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationDestination(isPresented: $showingTest) {
            if let launchedSession {
                TestRunView(deck: deck, snapshot: launchedSession)
            }
        }
        .navigationTitle("Configurer le test")
        .tint(accent)
        .background {
            Color.clear
                .alert("test.progress.reset.title", isPresented: $confirmingReset) {
                    Button("Réinitialiser", role: .destructive) { resetProgress() }
                    Button("Annuler", role: .cancel) {}
                        .normalActionColor()
                } message: {
                    Text("test.progress.reset.message")
                }
                .tint(.white)
        }
        .background {
            Color.clear
                .alert("test.new_series.title", isPresented: $confirmingNewSeries) {
                    Button("Continuer", role: .destructive) {
                        LibraryActions.resetTestProgress(for: deck, in: modelContext)
                        startNewSession()
                    }
                    .destructiveActionColor()
                    Button("Annuler", role: .cancel) {}
                        .normalActionColor()
                } message: {
                    Text("test.new_series.message")
                }
                .tint(.white)
        }
        .onAppear {
            if let resumableSession {
                selectedTypes = resumableSession.selectedTypes
                direction = resumableSession.direction
                shuffle = resumableSession.shuffle
                starredOnly = resumableSession.starredOnly
                sessionSize = resumableSession.sessionSize
            } else {
                normalizeSelectedTypes()
            }
        }
    }

    private func typeBinding(_ type: TestQuestionType) -> Binding<Bool> {
        Binding(
            get: { selectedTypes.contains(type) },
            set: { isSelected in
                if isSelected {
                    guard isTypeAvailable(type) else { return }
                    selectedTypes.insert(type)
                } else {
                    selectedTypes.remove(type)
                }
            }
        )
    }

    private func isTypeAvailable(_ type: TestQuestionType) -> Bool {
        configuration.mode == .useFlashcards || selectableAvailability.count(for: type) > 0
    }

    private func normalizeSelectedTypes() {
        guard configuration.mode != .useFlashcards else { return }
        selectedTypes = Set(selectedTypes.filter(isTypeAvailable))
    }

    private func snapshots(for cards: [Card]) -> [TestCardSnapshot] {
        cards.map {
            TestCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition)
        }
    }

    private func resetProgress() {
        LibraryActions.resetTestProgress(for: deck, in: modelContext)
    }

    private func startNewSession() {
        var cards = eligibleCards.sorted { $0.position < $1.position }
        let questions: [TestQuestion]

        if configuration.mode == .useFlashcards {
            if shuffle { cards.shuffle() }
            if let limit = sessionSize.limit {
                cards = Array(cards.prefix(limit))
            }
            let cardSnapshots = snapshots(for: cards)
            questions = TestQuestionFactory.makeQuestions(
                cards: cardSnapshots,
                types: selectedTypes,
                count: cardSnapshots.count,
                direction: direction,
                shuffle: shuffle
            )
        } else {
            let cardSnapshots = snapshots(for: cards)
            let questionCount = availability.total(for: selectedTypes)
            questions = AuthoredTestQuestionFactory.makeQuestions(
                cards: cardSnapshots,
                configuration: configuration,
                types: selectedTypes,
                count: min(sessionSize.limit ?? questionCount, questionCount),
                direction: direction,
                shuffle: shuffle
            )
        }

        guard !questions.isEmpty else { return }
        let snapshot = ActiveTestSessionSnapshot(
            deckID: deck.id,
            sessionNumber: deck.completedTestSessions + 1,
            selectedTypes: selectedTypes,
            direction: direction,
            shuffle: shuffle,
            starredOnly: starredOnly,
            sessionSize: sessionSize,
            state: TestSessionState(questions: questions)
        )
        launchedSession = snapshot
        showingTest = true
    }

    private func resume(_ snapshot: ActiveTestSessionSnapshot) {
        deck.lastTestActivityAt = .now
        try? modelContext.save()
        launchedSession = snapshot
        showingTest = true
    }
}
