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
    @State private var multipleChoiceToEdit: AuthoredMultipleChoiceQuestion?
    @State private var trueFalseToEdit: AuthoredTrueFalseQuestion?
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

    private var validCardIDs: Set<UUID> { Set(sourceCards.map(\.id)) }

    private var validatedConfiguration: DeckTestConfiguration? {
        guard draft.authoredQuestionCount > 0 else { return nil }
        return try? draft.validated(validCardIDs: validCardIDs)
    }

    private var accent: Color {
        deck.map { Theme.deckAccent(for: $0) } ?? Theme.accent
    }

    var body: some View {
        List {
            multipleChoiceSection
            trueFalseSection

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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .normalActionColor()
                .disabled(sourceCards.isEmpty)
            } footer: {
                validationFooter
            }
        }
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
                CircularSaveButton(accent: accent, isEnabled: validatedConfiguration != nil) {
                    complete()
                }
            }
        }
        .sheet(item: $multipleChoiceToEdit) { question in
            MultipleChoiceQuestionEditor(
                question: question,
                sourceCards: sourceCards,
                accent: accent,
                onSave: upsert
            )
        }
        .sheet(item: $trueFalseToEdit) { question in
            TrueFalseQuestionEditor(
                question: question,
                sourceCards: sourceCards,
                accent: accent,
                onSave: upsert
            )
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

    private var multipleChoiceSection: some View {
        Section {
            if draft.multipleChoice.isEmpty {
                emptyRow
            } else {
                ForEach(draft.multipleChoice) { question in
                    questionRow(
                        title: question.prompt,
                        sourceCardID: question.sourceCardID,
                        answer: question.correctAnswer ?? ""
                    ) {
                        multipleChoiceToEdit = question
                    }
                    .contextMenu {
                        deleteQuestionButton { removeMultipleChoice(question.id) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        swipeDeleteButton { removeMultipleChoice(question.id) }
                    }
                }
            }
        } header: {
            Text("\(L10n.text("test.type.multiple_choice")) (\(draft.multipleChoice.count))")
        }
    }

    private var trueFalseSection: some View {
        Section {
            if draft.trueFalse.isEmpty {
                emptyRow
            } else {
                ForEach(draft.trueFalse) { question in
                    questionRow(
                        title: question.statement,
                        sourceCardID: question.sourceCardID,
                        answer: question.correctAnswer
                            ? L10n.text("test.true")
                            : L10n.text("test.false")
                    ) {
                        trueFalseToEdit = question
                    }
                    .contextMenu {
                        deleteQuestionButton { removeTrueFalse(question.id) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        swipeDeleteButton { removeTrueFalse(question.id) }
                    }
                }
            }
        } header: {
            Text("\(L10n.text("test.type.true_false")) (\(draft.trueFalse.count))")
        }
    }

    private var emptyRow: some View {
        Text("test.editor.no_questions_in_section")
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var validationFooter: some View {
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

    private func questionRow(
        title: String,
        sourceCardID: UUID,
        answer: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticService.play(.selection)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                if let sourceCard = sourceCards.first(where: { $0.id == sourceCardID }) {
                    Label(sourceCard.term, systemImage: "rectangle.on.rectangle")
                        .lineLimit(1)
                }

                if !answer.isEmpty {
                    Label(answer, systemImage: "checkmark.circle")
                        .lineLimit(2)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func deleteQuestionButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label("test.editor.delete_question", systemImage: "trash")
        }
        .tint(.red)
    }

    private func swipeDeleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label("test.editor.delete_question", systemImage: "trash")
        }
    }

    private func addMultipleChoice() {
        guard let sourceCardID = sourceCards.first?.id else { return }
        HapticService.play(.selection)
        multipleChoiceToEdit = AuthoredMultipleChoiceQuestion(
            sourceCardID: sourceCardID,
            prompt: "",
            choices: ["", ""],
            correctChoiceIndex: 0
        )
    }

    private func addTrueFalse() {
        guard let sourceCardID = sourceCards.first?.id else { return }
        HapticService.play(.selection)
        trueFalseToEdit = AuthoredTrueFalseQuestion(
            sourceCardID: sourceCardID,
            statement: "",
            correctAnswer: true
        )
    }

    private func upsert(_ question: AuthoredMultipleChoiceQuestion) {
        if let index = draft.multipleChoice.firstIndex(where: { $0.id == question.id }) {
            draft.multipleChoice[index] = question
        } else {
            draft.multipleChoice.append(question)
        }
    }

    private func upsert(_ question: AuthoredTrueFalseQuestion) {
        if let index = draft.trueFalse.firstIndex(where: { $0.id == question.id }) {
            draft.trueFalse[index] = question
        } else {
            draft.trueFalse.append(question)
        }
    }

    private func removeMultipleChoice(_ id: UUID) {
        draft.multipleChoice.removeAll { $0.id == id }
        HapticService.play(.selection)
    }

    private func removeTrueFalse(_ id: UUID) {
        draft.trueFalse.removeAll { $0.id == id }
        HapticService.play(.selection)
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

private struct MultipleChoiceQuestionEditor: View {
    @Environment(\.dismiss) private var dismiss

    let sourceCards: [ExternalAISourceCard]
    let accent: Color
    let onSave: (AuthoredMultipleChoiceQuestion) -> Void

    @State private var question: AuthoredMultipleChoiceQuestion

    init(
        question: AuthoredMultipleChoiceQuestion,
        sourceCards: [ExternalAISourceCard],
        accent: Color,
        onSave: @escaping (AuthoredMultipleChoiceQuestion) -> Void
    ) {
        self.sourceCards = sourceCards
        self.accent = accent
        self.onSave = onSave
        _question = State(initialValue: question)
    }

    private var validatedQuestion: AuthoredMultipleChoiceQuestion? {
        try? question.validated(validCardIDs: Set(sourceCards.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("test.editor.question", text: $question.prompt, axis: .vertical)
                        .lineLimit(2...5)
                    SourceCardPicker(sourceCards: sourceCards, selection: $question.sourceCardID)
                }

                Section {
                    ForEach(question.choices.indices, id: \.self) { index in
                        choiceRow(at: index)
                            .contextMenu {
                                if question.choices.count > 2 {
                                    deleteChoiceButton(at: index)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if question.choices.count > 2 {
                                    deleteChoiceButton(at: index)
                                }
                            }
                    }

                    if question.choices.count < 6 {
                        Button("test.editor.add_choice", systemImage: "plus") {
                            question.choices.append("")
                            HapticService.play(.selection)
                        }
                        .normalActionColor()
                    }
                } header: {
                    Text("test.editor.choices")
                } footer: {
                    if validatedQuestion == nil {
                        Text("test.editor.validation_error")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("test.editor.edit_multiple_choice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    CircularSaveButton(accent: accent, isEnabled: validatedQuestion != nil) {
                        guard let validatedQuestion else { return }
                        onSave(validatedQuestion)
                        dismiss()
                    }
                }
            }
        }
    }

    private func choiceRow(at index: Int) -> some View {
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
                    question.correctChoiceIndex == index ? accent : Color.secondary
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
        }
        .contentShape(.rect)
    }

    private func deleteChoiceButton(at index: Int) -> some View {
        Button(role: .destructive) {
            removeChoice(at: index)
        } label: {
            Label("test.editor.remove_choice", systemImage: "trash")
        }
        .tint(.red)
    }

    private func removeChoice(at index: Int) {
        guard question.choices.indices.contains(index), question.choices.count > 2 else { return }
        question.choices.remove(at: index)
        if question.correctChoiceIndex == index {
            question.correctChoiceIndex = 0
        } else if question.correctChoiceIndex > index {
            question.correctChoiceIndex -= 1
        }
        HapticService.play(.selection)
    }
}

private struct TrueFalseQuestionEditor: View {
    @Environment(\.dismiss) private var dismiss

    let sourceCards: [ExternalAISourceCard]
    let accent: Color
    let onSave: (AuthoredTrueFalseQuestion) -> Void

    @State private var question: AuthoredTrueFalseQuestion

    init(
        question: AuthoredTrueFalseQuestion,
        sourceCards: [ExternalAISourceCard],
        accent: Color,
        onSave: @escaping (AuthoredTrueFalseQuestion) -> Void
    ) {
        self.sourceCards = sourceCards
        self.accent = accent
        self.onSave = onSave
        _question = State(initialValue: question)
    }

    private var validatedQuestion: AuthoredTrueFalseQuestion? {
        try? question.validated(validCardIDs: Set(sourceCards.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("test.editor.statement", text: $question.statement, axis: .vertical)
                        .lineLimit(2...5)
                    SourceCardPicker(sourceCards: sourceCards, selection: $question.sourceCardID)
                    Picker("test.editor.correct_answer", selection: $question.correctAnswer) {
                        Text("test.false").tag(false)
                        Text("test.true").tag(true)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if validatedQuestion == nil {
                        Text("test.editor.validation_error")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("test.editor.edit_true_false")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    CircularSaveButton(accent: accent, isEnabled: validatedQuestion != nil) {
                        guard let validatedQuestion else { return }
                        onSave(validatedQuestion)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SourceCardPicker: View {
    let sourceCards: [ExternalAISourceCard]
    @Binding var selection: UUID

    var body: some View {
        Picker("test.editor.source_card", selection: $selection) {
            ForEach(sourceCards) { sourceCard in
                VStack(alignment: .leading) {
                    Text(sourceCard.term)
                    Text(sourceCard.definition)
                        .foregroundStyle(.secondary)
                }
                .tag(sourceCard.id)
            }
        }
    }
}
