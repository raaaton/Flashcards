import SwiftData
import SwiftUI

struct TestRunView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck

    private let selectedTypes: Set<TestQuestionType>
    private let direction: StudyDirection
    private let shuffle: Bool
    private let starredOnly: Bool
    private let sessionSize: SessionSize

    @State private var session: TestSessionState
    @State private var sessionNumber: Int
    @State private var writtenAnswer = ""
    @State private var selectedAnswer: String?
    @State private var feedbackIsCorrect: Bool?
    @State private var isTransitioning = false
    @State private var didCelebrate = false
    @State private var didRecordCompletion = false
    @State private var showCelebration = false
    @State private var confirmingReset = false
    @State private var cardToEdit: Card?
    @State private var cardBeforeEditing: TestCardSnapshot?
    @FocusState private var writtenFieldIsFocused: Bool

    init(
        deck: Deck,
        snapshot: ActiveTestSessionSnapshot
    ) {
        self.deck = deck
        selectedTypes = snapshot.selectedTypes
        direction = snapshot.direction
        shuffle = snapshot.shuffle
        starredOnly = snapshot.starredOnly
        sessionSize = snapshot.sessionSize
        _session = State(initialValue: snapshot.state)
        _sessionNumber = State(initialValue: snapshot.sessionNumber)

        let currentAnswer = snapshot.state.currentAnswer
        _writtenAnswer = State(
            initialValue: currentAnswer?.question.type == .written
                ? currentAnswer?.givenAnswer ?? ""
                : ""
        )
        _selectedAnswer = State(initialValue: currentAnswer?.givenAnswer)
        _feedbackIsCorrect = State(initialValue: currentAnswer?.isCorrect)
    }

    private var accent: Color { Theme.deckAccent(for: deck) }

    var body: some View {
        ZStack {
            if session.isComplete {
                resultsView
                    .transition(questionTransition)
            } else if let question = session.currentQuestion {
                questionView(question)
                    .id(question.id)
                    .transition(questionTransition)
            }
        }
        .navigationBarBackButtonHidden()
        .tint(accent)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .neutralIconColor()
                }
                .tint(.white)
                .accessibilityLabel("Quitter")
            }

            if !session.isComplete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard feedbackIsCorrect == nil,
                              !isTransitioning,
                              let card = currentDeckCard else { return }
                        HapticService.play(.selection)
                        cardBeforeEditing = TestCardSnapshot(
                            id: card.id,
                            term: card.term,
                            definition: card.definition
                        )
                        cardToEdit = card
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .neutralIconColor()
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                    .disabled(
                        feedbackIsCorrect != nil
                            || isTransitioning
                            || currentDeckCard == nil
                    )
                    .accessibilityLabel(L10n.text("card.edit.title"))
                }
            }
        }
        .sheet(item: $cardToEdit) { card in
            CardFormView(deck: deck, card: card) {
                refreshSourceCard(from: card)
            }
        }
        .overlay {
            if showCelebration {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
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
    }

    private var questionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: TestAnimationMetrics.transitionScale)),
            removal: .move(edge: .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: TestAnimationMetrics.transitionScale))
        )
    }

    private func questionView(_ question: TestQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader

                Text(question.type.title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)

                Text(question.prompt)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let secondaryText = question.secondaryText {
                    Text(secondaryText)
                        .font(.title2)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
                }

                switch question.type {
                case .multipleChoice:
                    multipleChoiceAnswers(question)
                case .trueFalse:
                    trueFalseAnswers(question)
                case .written:
                    writtenAnswerForm(question)
                }

                if let feedbackIsCorrect {
                    feedbackBanner(isCorrect: feedbackIsCorrect, question: question)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                    Button {
                        advanceAfterFeedback()
                    } label: {
                        Text(session.isLastQuestion ? "test.see_results" : "common.next")
                            .font(.headline)
                            .foregroundStyle(Theme.foreground(on: accent))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                accent,
                                in: .rect(cornerRadius: 16, style: .continuous)
                            )
                            .contentShape(.rect(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTransitioning)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressHeader: some View {
        VStack(spacing: 9) {
            HStack {
                Text(L10n.format(
                    "test.question.progress",
                    Int64(session.currentIndex + 1),
                    Int64(session.questions.count)
                ))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(session.answers.count) / \(session.questions.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(session.answers.count),
                total: Double(max(session.questions.count, 1))
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.2),
                value: session.answers.count
            )
            .accessibilityLabel("Progression du test")
            .accessibilityValue(
                L10n.format(
                    "test.progress.value",
                    Int64(session.answers.count),
                    Int64(session.questions.count)
                )
            )
        }
    }

    private func multipleChoiceAnswers(_ question: TestQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.choices, id: \.self) { choice in
                Button {
                    submit(choice)
                } label: {
                    Text(choice)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(choiceFill(choice, question: question))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(choiceStroke(choice, question: question), lineWidth: 1.5)
                        }
                        .clipShape(.rect(cornerRadius: 14, style: .continuous))
                        .scaleEffect(selectedAnswer == choice ? 1.012 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isTransitioning || feedbackIsCorrect != nil)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selectedAnswer)
    }

    private func trueFalseAnswers(_ question: TestQuestion) -> some View {
        HStack(spacing: 12) {
            verdictButton(
                canonicalAnswer: "Faux",
                title: L10n.text("test.false"),
                systemImage: "xmark",
                question: question
            )
            verdictButton(
                canonicalAnswer: "Vrai",
                title: L10n.text("test.true"),
                systemImage: "checkmark",
                question: question
            )
        }
    }

    private func verdictButton(
        canonicalAnswer: String,
        title: String,
        systemImage: String,
        question: TestQuestion
    ) -> some View {
        Button {
            submit(canonicalAnswer)
        } label: {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.bold))
                    .frame(width: 34, height: 34)
                    .background(
                        verdictSymbolBackground(canonicalAnswer, question: question),
                        in: .circle
                    )

                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(verdictForeground(canonicalAnswer, question: question))
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(
                verdictBackground(canonicalAnswer, question: question),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        verdictStroke(canonicalAnswer, question: question),
                        lineWidth: 1.5
                    )
            }
            .contentShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedAnswer == canonicalAnswer ? 1.025 : 1)
        .disabled(isTransitioning || feedbackIsCorrect != nil)
        .animation(.easeOut(duration: 0.15), value: selectedAnswer)
    }

    private func writtenAnswerForm(_ question: TestQuestion) -> some View {
        let canSubmit = !isTransitioning
            && feedbackIsCorrect == nil
            && !writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(spacing: 12) {
            TextField("Votre réponse", text: $writtenAnswer, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    Theme.cardBackground,
                    in: .rect(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            writtenFieldIsFocused ? accent : Theme.subtleStroke,
                            lineWidth: writtenFieldIsFocused ? 1.5 : 1
                        )
                }
                .submitLabel(.done)
                .focused($writtenFieldIsFocused)
                .disabled(isTransitioning || feedbackIsCorrect != nil)
                .onSubmit { submitWrittenAnswer() }

            Button {
                submitWrittenAnswer()
            } label: {
                Label("Valider", systemImage: "checkmark")
                    .font(.headline)
                    .foregroundStyle(
                        canSubmit ? Theme.foreground(on: accent) : Color.secondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        canSubmit ? accent : Theme.cardBackground,
                        in: .rect(cornerRadius: 16, style: .continuous)
                    )
                    .contentShape(.rect(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
    }

    private func feedbackBanner(isCorrect: Bool, question: TestQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                isCorrect ? L10n.text("common.correct") : L10n.text("study.review"),
                systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(isCorrect ? .green : .red)

            if !isCorrect {
                Text(L10n.format("test.correct_answer", displayAnswer(question.correctAnswer, question: question)))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: .rect(cornerRadius: 14, style: .continuous))
    }

    private var resultsView: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: session.score == 100 ? "checkmark.seal.fill" : "chart.bar.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(accent)
                    Text("\(session.score) %")
                        .font(.largeTitle.bold())
                    Text(L10n.format(
                        "test.result.summary",
                        Int64(session.correctCount),
                        Int64(session.answers.count)
                    ))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

            Section("Revue") {
                ForEach(session.answers) { record in
                    answerReview(record)
                }
            }

            Section {
                if session.answers.contains(where: { !$0.isCorrect }) {
                    Button("Refaire uniquement les erreurs", systemImage: "arrow.counterclockwise") {
                        retryErrors()
                    }
                    .normalActionColor(accent)
                }
                Button("Terminer", systemImage: "checkmark") { dismiss() }
                    .normalActionColor(accent)

                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Label("test.progress.reset.deck_action", systemImage: "trash")
                }
                .destructiveActionColor()
            }
        }
        .navigationTitle("Résultats")
    }

    private func answerReview(_ record: TestAnswerRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                record.isCorrect ? L10n.text("common.correct") : L10n.text("study.review"),
                systemImage: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(record.isCorrect ? .green : .red)
            .font(.headline)

            Text(record.question.prompt)
                .font(.headline)
            Text(L10n.format(
                "test.given_answer",
                displayAnswer(record.givenAnswer, question: record.question)
            ))
            Text(L10n.format(
                "test.correct_answer",
                displayAnswer(record.question.correctAnswer, question: record.question)
            ))
                .foregroundStyle(.secondary)
            if record.question.type == .trueFalse,
               let referenceAnswer = record.question.referenceAnswer {
                Text(L10n.format("test.correct_pairing", referenceAnswer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if record.wasOverridden {
                Text("Correction validée manuellement")
                    .font(.caption)
                    .foregroundStyle(accent)
            } else if !record.isCorrect && record.question.type == .written {
                Button("C’était correct en fait") {
                    override(record)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    private func choiceFill(_ choice: String, question: TestQuestion) -> Color {
        guard selectedAnswer != nil else { return Theme.cardBackground }
        if answersMatch(choice, question.correctAnswer) {
            return .green.opacity(0.2)
        }
        if selectedAnswer == choice {
            return .red.opacity(0.2)
        }
        return Theme.cardBackground
    }

    private func choiceStroke(_ choice: String, question: TestQuestion) -> Color {
        guard selectedAnswer != nil else { return .secondary.opacity(0.45) }
        if answersMatch(choice, question.correctAnswer) { return .green }
        if selectedAnswer == choice { return .red }
        return .secondary.opacity(0.25)
    }

    private func verdictBackground(_ answer: String, question: TestQuestion) -> Color {
        guard selectedAnswer != nil else { return Theme.cardBackground }
        if answersMatch(answer, question.correctAnswer) { return .green.opacity(0.22) }
        if selectedAnswer == answer { return .red.opacity(0.22) }
        return Theme.cardBackground.opacity(0.7)
    }

    private func verdictStroke(_ answer: String, question: TestQuestion) -> Color {
        guard selectedAnswer != nil else { return Theme.subtleStroke }
        if answersMatch(answer, question.correctAnswer) { return .green }
        if selectedAnswer == answer { return .red }
        return Theme.subtleStroke
    }

    private func verdictSymbolBackground(_ answer: String, question: TestQuestion) -> Color {
        let color: Color = answer == "Vrai" ? .green : .red
        guard selectedAnswer != nil else { return color.opacity(0.18) }
        if answersMatch(answer, question.correctAnswer) || selectedAnswer == answer {
            return color
        }
        return color.opacity(0.12)
    }

    private func verdictForeground(_ answer: String, question: TestQuestion) -> Color {
        guard selectedAnswer != nil else { return .primary }
        if answersMatch(answer, question.correctAnswer) || selectedAnswer == answer {
            return .primary
        }
        return .secondary
    }

    private func answersMatch(_ lhs: String, _ rhs: String) -> Bool {
        TestQuestionFactory.normalize(lhs) == TestQuestionFactory.normalize(rhs)
    }

    private func displayAnswer(_ answer: String, question: TestQuestion) -> String {
        guard question.type == .trueFalse else { return answer }
        return answer == "Vrai" ? L10n.text("test.true") : L10n.text("test.false")
    }

    private func submitWrittenAnswer() {
        let cleanAnswer = writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAnswer.isEmpty else { return }
        submit(cleanAnswer)
    }

    private var currentDeckCard: Card? {
        guard let cardID = session.currentQuestion?.cardID else { return nil }
        return deck.cards.first(where: { $0.id == cardID })
    }

    private func refreshSourceCard(from card: Card) {
        guard let previous = cardBeforeEditing, previous.id == card.id else { return }
        let updated = TestCardSnapshot(
            id: card.id,
            term: card.term,
            definition: card.definition
        )
        session.refreshSourceCard(
            previous: previous,
            updated: updated,
            configurationMode: deck.testConfiguration.mode
        )
        cardBeforeEditing = nil
        deck.updatedAt = .now
        if session.currentIndex > 0 || !session.answers.isEmpty {
            persistActiveSession()
        }
        try? modelContext.save()
    }

    private func submit(_ answer: String) {
        guard !isTransitioning,
              feedbackIsCorrect == nil,
              session.currentQuestion != nil else { return }

        guard let record = session.submit(answer: answer) else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            selectedAnswer = answer
            feedbackIsCorrect = record.isCorrect
        }
        writtenFieldIsFocused = false
        HapticService.play(record.isCorrect ? .correct : .wrong)
        persist(record)
    }

    private func advanceAfterFeedback() {
        guard !isTransitioning, session.currentAnswer != nil else { return }
        isTransitioning = true
        HapticService.play(.selection)

        let completesTest = session.isLastQuestion
        let transitionAnimation: Animation = reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(
                response: TestAnimationMetrics.transitionResponse,
                dampingFraction: TestAnimationMetrics.transitionDamping
            )

        withAnimation(transitionAnimation) {
            _ = session.advance()
            selectedAnswer = nil
            feedbackIsCorrect = nil
            writtenAnswer = ""
        }

        if completesTest && session.score == 100 {
            celebratePerfectScore()
        }
        if completesTest {
            recordCompletedTestSession()
        } else {
            persistActiveSession()
            try? modelContext.save()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(TestAnimationMetrics.transitionMilliseconds))
            isTransitioning = false
        }
    }

    private func persist(_ record: TestAnswerRecord) {
        guard let card = deck.cards.first(where: { $0.id == record.question.cardID }) else { return }
        card.timesStudied += 1
        if record.isCorrect {
            card.timesCorrect += 1
        }
        updateTestMastery(for: card)
        deck.updatedAt = .now
        deck.lastTestActivityAt = .now
        persistActiveSession()
        try? modelContext.save()
    }

    private func override(_ record: TestAnswerRecord) {
        guard let cardID = session.overrideWrittenAnswer(questionID: record.id),
              let card = deck.cards.first(where: { $0.id == cardID }) else { return }
        card.timesCorrect += 1
        updateTestMastery(for: card)
        deck.updatedAt = .now
        deck.lastTestActivityAt = .now
        try? modelContext.save()
        HapticService.play(.correct)

        if session.score == 100 {
            celebratePerfectScore()
        }
    }

    private func retryErrors() {
        sessionNumber = deck.completedTestSessions + 1
        didRecordCompletion = false
        didCelebrate = false
        showCelebration = false
        writtenAnswer = ""
        selectedAnswer = nil
        feedbackIsCorrect = nil
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(
                    response: TestAnimationMetrics.transitionResponse,
                    dampingFraction: TestAnimationMetrics.transitionDamping
                )
        ) {
            session.retryErrors()
        }
        deck.activeTestSessionData = nil
        deck.lastTestActivityAt = .now
        deck.updatedAt = .now
        try? modelContext.save()
    }

    private func recordCompletedTestSession() {
        guard !didRecordCompletion else { return }
        didRecordCompletion = true
        deck.completedTestSessions = sessionNumber
        deck.activeTestSessionData = nil
        deck.recordCompletedSession(
            mode: .test,
            itemCount: session.answers.count,
            correctCount: session.correctCount,
            incorrectCount: session.answers.count - session.correctCount
        )
        deck.lastTestActivityAt = .now
        deck.updatedAt = .now
        try? modelContext.save()
    }

    private func persistActiveSession() {
        let snapshot = ActiveTestSessionSnapshot(
            deckID: deck.id,
            sessionNumber: sessionNumber,
            selectedTypes: selectedTypes,
            direction: direction,
            shuffle: shuffle,
            starredOnly: starredOnly,
            sessionSize: sessionSize,
            state: session
        )
        deck.activeTestSessionData = try? TestSessionPersistence.encode(snapshot)
    }

    private func updateTestMastery(for card: Card) {
        guard let isMastered = session.masteryStatus(for: card.id) else { return }
        card.testMastered = isMastered
    }

    private func resetProgress() {
        LibraryActions.resetTestProgress(for: deck, in: modelContext)
        dismiss()
    }

    private func celebratePerfectScore() {
        guard !didCelebrate else { return }
        didCelebrate = true
        HapticService.play(.completion)
        showCelebration = AppPreferences.celebrationsEnabled && !reduceMotion
    }
}
