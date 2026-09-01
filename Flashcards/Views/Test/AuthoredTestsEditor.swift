import SwiftData
import SwiftUI

struct AuthoredTestsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let deck: Deck?
    private let sourceCards: [ExternalAISourceCard]
    private let onBack: ((DeckTestConfiguration) -> Void)?
    private let onComplete: ((DeckTestConfiguration) -> Void)?

    @State private var draft: DeckTestConfiguration
    @State private var saveErrorMessage: String?

    init(deck: Deck) {
        self.deck = deck
        sourceCards = deck.cards
            .sorted { $0.position < $1.position }
            .map { ExternalAISourceCard(id: $0.id, term: $0.term, definition: $0.definition) }
        onBack = nil
        onComplete = nil
        _draft = State(initialValue: deck.testConfiguration)
    }

    init(
        sourceCards: [ExternalAISourceCard],
        configuration: DeckTestConfiguration,
        onBack: @escaping (DeckTestConfiguration) -> Void,
        onComplete: @escaping (DeckTestConfiguration) -> Void
    ) {
        deck = nil
        self.sourceCards = sourceCards
        self.onBack = onBack
        self.onComplete = onComplete
        _draft = State(initialValue: configuration)
    }

    private var validCardIDs: Set<UUID> {
        Set(sourceCards.map(\.id))
    }

    private var validatedConfiguration: DeckTestConfiguration? {
        guard draft.authoredQuestionCount > 0 else { return nil }
        return try? draft.validated(validCardIDs: validCardIDs)
    }

    var body: some View {
        Form {
            multipleChoiceSections
            trueFalseSections

            Section {
                Menu {
                    Button("test.editor.add_multiple_choice", systemImage: "list.bullet.circle") {
                        addMultipleChoice()
                    }
                    Button("test.editor.add_true_false", systemImage: "checkmark.circle") {
                        addTrueFalse()
                    }
                } label: {
                    Label("test.editor.add_question", systemImage: "plus")
                }
                .normalActionColor()
                .disabled(sourceCards.isEmpty)
            } footer: {
                if sourceCards.isEmpty {
                    Text("test.editor.no_source_cards")
                        .foregroundStyle(.red)
                } else if draft.authoredQuestionCount == 0 {
                    Text("test.editor.minimum_one")
                } else if validatedConfiguration == nil {
                    Text("test.editor.validation_error")
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("test.editor.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onBack != nil)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onBack(draft)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .tint(.white)
                    .accessibilityLabel("common.back")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                CircularSaveButton(
                    accent: deck.map { Theme.deckAccent(for: $0) } ?? Theme.accent,
                    isEnabled: validatedConfiguration != nil
                ) {
                    complete()
                }
            }
        }
        .alert(
            L10n.text("test.editor.save_error_title"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
                .normalActionColor()
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .tint(.white)
    }

    @ViewBuilder
    private var multipleChoiceSections: some View {
        ForEach($draft.multipleChoice) { $question in
            Section {
                TextField("test.editor.question", text: $question.prompt, axis: .vertical)
                    .lineLimit(2...5)

                sourcePicker(selection: $question.sourceCardID)

                ForEach(question.choices.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        Button {
                            question.correctChoiceIndex = index
                        } label: {
                            Image(
                                systemName: question.correctChoiceIndex == index
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                question.correctChoiceIndex == index
                                    ? Theme.accent
                                    : Color.secondary
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            question.correctChoiceIndex == index
                                ? L10n.text("test.editor.correct_choice_selected")
                                : L10n.text("test.editor.mark_correct_choice")
                        )

                        TextField(
                            L10n.format("test.editor.choice", Int64(index + 1)),
                            text: $question.choices[index],
                            axis: .vertical
                        )

                        if question.choices.count > 2 {
                            Button(role: .destructive) {
                                removeChoice(at: index, from: $question)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .tint(.red)
                            .accessibilityLabel("test.editor.remove_choice")
                        }
                    }
                }

                if question.choices.count < 6 {
                    Button("test.editor.add_choice", systemImage: "plus") {
                        question.choices.append("")
                    }
                    .normalActionColor()
                }

                Button(role: .destructive) {
                    removeMultipleChoice(question.id)
                } label: {
                    Label("test.editor.delete_question", systemImage: "trash")
                }
                .tint(.red)
            } header: {
                Text("test.type.multiple_choice")
            }
        }
    }

    @ViewBuilder
    private var trueFalseSections: some View {
        ForEach($draft.trueFalse) { $question in
            Section {
                TextField("test.editor.statement", text: $question.statement, axis: .vertical)
                    .lineLimit(2...5)

                sourcePicker(selection: $question.sourceCardID)

                Picker("test.editor.correct_answer", selection: $question.correctAnswer) {
                    Text("test.false").tag(false)
                    Text("test.true").tag(true)
                }
                .pickerStyle(.segmented)

                Button(role: .destructive) {
                    removeTrueFalse(question.id)
                } label: {
                    Label("test.editor.delete_question", systemImage: "trash")
                }
                .tint(.red)
            } header: {
                Text("test.type.true_false")
            }
        }
    }

    private func sourcePicker(selection: Binding<UUID>) -> some View {
        Picker("test.editor.source_card", selection: selection) {
            ForEach(sourceCards) { card in
                VStack(alignment: .leading) {
                    Text(card.term)
                    Text(card.definition)
                        .foregroundStyle(.secondary)
                }
                .tag(card.id)
            }
        }
    }

    private func addMultipleChoice() {
        guard let sourceCardID = sourceCards.first?.id else { return }
        draft.multipleChoice.append(
            AuthoredMultipleChoiceQuestion(
                sourceCardID: sourceCardID,
                prompt: "",
                choices: ["", ""],
                correctChoiceIndex: 0
            )
        )
        HapticService.play(.selection)
    }

    private func addTrueFalse() {
        guard let sourceCardID = sourceCards.first?.id else { return }
        draft.trueFalse.append(
            AuthoredTrueFalseQuestion(
                sourceCardID: sourceCardID,
                statement: "",
                correctAnswer: true
            )
        )
        HapticService.play(.selection)
    }

    private func removeChoice(
        at index: Int,
        from question: Binding<AuthoredMultipleChoiceQuestion>
    ) {
        var value = question.wrappedValue
        guard value.choices.indices.contains(index), value.choices.count > 2 else { return }
        value.choices.remove(at: index)
        if value.correctChoiceIndex == index {
            value.correctChoiceIndex = 0
        } else if value.correctChoiceIndex > index {
            value.correctChoiceIndex -= 1
        }
        question.wrappedValue = value
    }

    private func removeMultipleChoice(_ id: UUID) {
        draft.multipleChoice.removeAll { $0.id == id }
    }

    private func removeTrueFalse(_ id: UUID) {
        draft.trueFalse.removeAll { $0.id == id }
    }

    private func complete() {
        guard let validatedConfiguration else { return }
        if let deck {
            deck.setTestConfiguration(validatedConfiguration)
            deck.updatedAt = .now
            do {
                try modelContext.save()
                dismiss()
            } catch {
                modelContext.rollback()
                saveErrorMessage = error.localizedDescription
            }
        } else {
            onComplete?(validatedConfiguration)
        }
    }
}
