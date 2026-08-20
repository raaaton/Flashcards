import SwiftData
import SwiftUI

struct TestSetupView: View {
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var selectedTypes = Set(TestQuestionType.allCases)
    @State private var direction = StudyDirection.termToDefinition
    @State private var shuffle = true
    @State private var starredOnly = false
    @State private var sessionSize = SessionSize.all
    @State private var showingTest = false

    init(deck: Deck) {
        self.deck = deck
    }

    private var eligibleCards: [Card] {
        deck.cards.filter { !starredOnly || $0.isStarred }
    }

    private var effectiveCount: Int {
        min(sessionSize.limit ?? eligibleCards.count, eligibleCards.count)
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
                        Toggle(type.title, isOn: typeBinding(type))
                    }
                } header: {
                    Text("Types de questions")
                } footer: {
                    if selectedTypes.isEmpty {
                        Text("Sélectionnez au moins un type de question.")
                    }
                }

                Section("Sens") {
                    LabeledContent("Sens") {
                        StudyDirectionMenu(selection: $direction, accent: accent)
                    }
                }

                Section("Options") {
                    Toggle("Mélanger", isOn: $shuffle)
                    Toggle("study.starred_only", isOn: $starredOnly)
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
    }

    private func typeBinding(_ type: TestQuestionType) -> Binding<Bool> {
        Binding(
            get: { selectedTypes.contains(type) },
            set: { isSelected in
                if isSelected {
                    selectedTypes.insert(type)
                } else {
                    selectedTypes.remove(type)
                }
            }
        )
    }
}
