import SwiftData
import SwiftUI

struct TestRunView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck

    @State private var session: TestSessionState
    @State private var writtenAnswer = ""
    @State private var selectedAnswer: String?
    @State private var feedbackIsCorrect: Bool?
    @State private var isTransitioning = false
    @State private var didCelebrate = false
    @State private var showCelebration = false
    @FocusState private var writtenFieldIsFocused: Bool

    init(
        deck: Deck,
        types: Set<TestQuestionType>,
        questionCount: Int,
        direction: StudyDirection
    ) {
        self.deck = deck
        let cards = deck.cards
            .sorted { $0.position < $1.position }
            .map { TestCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition) }
        let questions = TestQuestionFactory.makeQuestions(
            cards: cards,
            types: types,
            count: questionCount,
            direction: direction
        )
        _session = State(initialValue: TestSessionState(questions: questions))
    }

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Quitter", systemImage: "xmark") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
        .overlay {
            if showCelebration {
                ConfettiView()
                    .ignoresSafeArea()
            }
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
                    .foregroundStyle(Theme.accent)

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
                Text("\(session.currentIndex) / \(session.questions.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(session.currentIndex),
                total: Double(max(session.questions.count, 1))
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.2),
                value: session.currentIndex
            )
            .accessibilityLabel("Progression du test")
            .accessibilityValue(
                L10n.format(
                    "test.progress.value",
                    Int64(session.currentIndex),
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
                .disabled(isTransitioning)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selectedAnswer)
    }

    private func trueFalseAnswers(_ question: TestQuestion) -> some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
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
    }

    private func verdictButton(
        canonicalAnswer: String,
        title: String,
        systemImage: String,
        question: TestQuestion
    ) -> some View {
        Button(title, systemImage: systemImage) { submit(canonicalAnswer) }
            .buttonStyle(.glassProminent)
            .tint(verdictTint(canonicalAnswer, question: question))
            .frame(maxWidth: .infinity)
            .scaleEffect(selectedAnswer == canonicalAnswer ? 1.025 : 1)
            .disabled(isTransitioning)
            .animation(.easeOut(duration: 0.15), value: selectedAnswer)
    }

    private func writtenAnswerForm(_ question: TestQuestion) -> some View {
        VStack(spacing: 16) {
            TextField("Votre réponse", text: $writtenAnswer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...6)
                .submitLabel(.done)
                .focused($writtenFieldIsFocused)
                .disabled(isTransitioning)
                .onSubmit { submitWrittenAnswer() }

            Button("Valider", systemImage: "checkmark") { submitWrittenAnswer() }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.white)
                .disabled(
                    isTransitioning
                        || writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
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
                        .foregroundStyle(Theme.accent)
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
                    .foregroundStyle(.white)
                }
                Button("Terminer", systemImage: "checkmark") { dismiss() }
                    .foregroundStyle(.white)
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
            if record.question.type == .trueFalse {
                Text(L10n.format("test.correct_pairing", record.question.referenceAnswer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if record.wasOverridden {
                Text("Correction validée manuellement")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
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

    private func verdictTint(_ answer: String, question: TestQuestion) -> Color {
        guard selectedAnswer != nil else { return answer == "Vrai" ? .green : .red }
        if answersMatch(answer, question.correctAnswer) { return .green }
        if selectedAnswer == answer { return .red }
        return .gray
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

    private func submit(_ answer: String) {
        guard !isTransitioning,
              let question = session.currentQuestion else { return }

        isTransitioning = true
        selectedAnswer = answer
        feedbackIsCorrect = answersMatch(answer, question.correctAnswer)
        writtenFieldIsFocused = false
        HapticService.play(feedbackIsCorrect == true ? .correct : .wrong)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(TestAnimationMetrics.feedbackMilliseconds))
            guard session.currentQuestion?.id == question.id else { return }

            let transitionAnimation: Animation = reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(
                    response: TestAnimationMetrics.transitionResponse,
                    dampingFraction: TestAnimationMetrics.transitionDamping
                )

            let record = withAnimation(transitionAnimation) {
                let submitted = session.submit(answer: answer)
                selectedAnswer = nil
                feedbackIsCorrect = nil
                writtenAnswer = ""
                return submitted
            }

            if let record {
                persist(record)
            }
            if session.isComplete && session.score == 100 {
                celebratePerfectScore()
            }

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
        deck.updatedAt = .now
        try? modelContext.save()
    }

    private func override(_ record: TestAnswerRecord) {
        guard let cardID = session.overrideWrittenAnswer(questionID: record.id),
              let card = deck.cards.first(where: { $0.id == cardID }) else { return }
        card.timesCorrect += 1
        deck.updatedAt = .now
        try? modelContext.save()
        HapticService.play(.correct)

        if session.score == 100 {
            celebratePerfectScore()
        }
    }

    private func retryErrors() {
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
    }

    private func celebratePerfectScore() {
        guard !didCelebrate else { return }
        didCelebrate = true
        HapticService.play(.completion)
        showCelebration = AppPreferences.celebrationsEnabled && !reduceMotion
    }
}
