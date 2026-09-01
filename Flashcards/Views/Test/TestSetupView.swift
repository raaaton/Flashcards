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

    init(deck: Deck) {
        self.deck = deck
    }

    private var eligibleCards: [Card] {
        deck.cards.filter { !starredOnly || $0.isStarred }
    }

    private var configuration: DeckTestConfiguration {
        deck.testConfiguration
    }

    private var eligibleSnapshots: [TestCardSnapshot] {
        eligibleCards.map {
            TestCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition)
        }
    }

    private var availability: AuthoredTestAvailability {
        AuthoredTestQuestionFactory.availability(
            cards: eligibleSnapshots,
            configuration: configuration
        )
    }

    private var effectiveCount: Int {
        let availableCount = configuration.mode == .useFlashcards
            ? eligibleCards.count
            : availability.total(for: selectedTypes)
        return min(sessionSize.limit ?? availableCount, availableCount)
    }

    private var hasStarredCards: Bool {
        deck.cards.contains(where: \.isStarred)
    }

    private var accent: Color { Theme.deckAccent(for: deck) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(TestQuestionType.allCases) { type in
                        HStack {
                            Toggle(type.title, isOn: typeBinding(type))
                                .disabled(!isTypeAvailable(type))

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
                }

                Section("Options") {
                    Toggle("Mélanger", isOn: $shuffle)
                        .onChange(of: shuffle) { _, newValue in
                            AppPreferences.studyShuffle = newValue
                        }
                    Toggle("study.starred_only", isOn: $starredOnly)
                        .onChange(of: starredOnly) { _, newValue in
                            AppPreferences.studyStarredOnly = newValue
                            normalizeSelectedTypes()
                        }
                }

                Section("session.size.title") {
                    Picker("session.size.title", selection: $sessionSize) {
                        ForEach(SessionSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Test prévu", value: L10n.questions(effectiveCount))
                }

                if starredOnly && !hasStarredCards {
                    Section {
                        Label("study.no_starred", systemImage: "star.slash")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            PrimaryStartButton(
                isEnabled: !selectedTypes.isEmpty && effectiveCount > 0,
                accent: accent
            ) {
                deck.lastStudyActivityAt = .now
                try? modelContext.save()
                showingTest = true
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationDestination(isPresented: $showingTest) {
            TestRunView(
                deck: deck,
                types: selectedTypes,
                direction: direction,
                shuffle: shuffle,
                starredOnly: starredOnly,
                sessionSize: sessionSize
            )
        }
        .navigationTitle("Configurer le test")
        .tint(accent)
        .onAppear(perform: normalizeSelectedTypes)
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
        configuration.mode == .useFlashcards || availability.count(for: type) > 0
    }

    private func normalizeSelectedTypes() {
        guard configuration.mode != .useFlashcards else { return }
        selectedTypes = Set(selectedTypes.filter(isTypeAvailable))
    }
}
