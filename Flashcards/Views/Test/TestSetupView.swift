import SwiftUI

struct TestSetupView: View {
    let deck: Deck

    @State private var selectedTypes = Set(TestQuestionType.allCases)
    @State private var direction = StudyDirection.termToDefinition
    @State private var useAllCards = true
    @State private var questionCount: Int

    init(deck: Deck) {
        self.deck = deck
        _questionCount = State(initialValue: min(max(deck.cards.count, 1), 10))
    }

    private var effectiveCount: Int {
        useAllCards ? deck.cards.count : min(questionCount, deck.cards.count)
    }

    var body: some View {
        Form {
            Section("Types de questions") {
                ForEach(TestQuestionType.allCases) { type in
                    Toggle(type.title, isOn: typeBinding(type))
                }
            }

            Section("Sens") {
                Picker("Sens des questions", selection: $direction) {
                    ForEach(StudyDirection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            Section("Nombre de questions") {
                Toggle("Tout le deck", isOn: $useAllCards)
                if !useAllCards {
                    Stepper(
                        "\(questionCount) question\(questionCount > 1 ? "s" : "")",
                        value: $questionCount,
                        in: 1...max(deck.cards.count, 1)
                    )
                }
                LabeledContent("Test prévu", value: "\(effectiveCount) question\(effectiveCount > 1 ? "s" : "")")
            }

            Section {
                NavigationLink {
                    TestRunView(
                        deck: deck,
                        types: selectedTypes,
                        questionCount: effectiveCount,
                        direction: direction
                    )
                } label: {
                    Label("Commencer le test", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedTypes.isEmpty || effectiveCount == 0)
            } footer: {
                if selectedTypes.isEmpty {
                    Text("Sélectionnez au moins un type de question.")
                }
            }
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
