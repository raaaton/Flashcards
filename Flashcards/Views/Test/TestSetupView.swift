import SwiftUI

struct TestSetupView: View {
    let deck: Deck

    @State private var selectedTypes = Set(TestQuestionType.allCases)
    @State private var direction = StudyDirection.termToDefinition
    @State private var shuffle = true
    @State private var useAllCards = true
    @State private var questionCount: Int
    @State private var showingTest = false

    init(deck: Deck) {
        self.deck = deck
        _questionCount = State(initialValue: min(max(deck.cards.count, 1), 10))
    }

    private var effectiveCount: Int {
        useAllCards ? deck.cards.count : min(questionCount, deck.cards.count)
    }

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
                        StudyDirectionMenu(selection: $direction)
                    }
                }

                Section("Options") {
                    Toggle("Mélanger", isOn: $shuffle)
                }

                Section("Nombre de questions") {
                    Toggle("Tout le deck", isOn: $useAllCards)
                    if !useAllCards {
                        Stepper(
                            L10n.questions(questionCount),
                            value: $questionCount,
                            in: 1...max(deck.cards.count, 1)
                        )
                    }
                    LabeledContent("Test prévu", value: L10n.questions(effectiveCount))
                }
            }

            PrimaryStartButton(
                isEnabled: !selectedTypes.isEmpty && effectiveCount > 0
            ) {
                showingTest = true
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationDestination(isPresented: $showingTest) {
            TestRunView(
                deck: deck,
                types: selectedTypes,
                questionCount: effectiveCount,
                direction: direction,
                shuffle: shuffle
            )
        }
        .navigationTitle("Configurer le test")
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
