import SwiftData
import SwiftUI

struct TestRunView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck
    @State private var session: TestSessionState
    @State private var writtenAnswer = ""

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
        Group {
            if session.isComplete {
                resultsView
            } else if let question = session.currentQuestion {
                questionView(question)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Quitter", systemImage: "xmark") { dismiss() }
            }
        }
    }

    private func questionView(_ question: TestQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProgressView(
                    value: Double(session.currentIndex),
                    total: Double(max(session.questions.count, 1))
                ) {
                    Text("Question \(session.currentIndex + 1) sur \(session.questions.count)")
                }

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
                    trueFalseAnswers
                case .written:
                    writtenAnswerForm
                }
            }
            .padding()
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func multipleChoiceAnswers(_ question: TestQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.choices, id: \.self) { choice in
                Button {
                    submit(choice)
                } label: {
                    Text(choice)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var trueFalseAnswers: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button("Faux", systemImage: "xmark") { submit("Faux") }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                Button("Vrai", systemImage: "checkmark") { submit("Vrai") }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var writtenAnswerForm: some View {
        VStack(spacing: 16) {
            TextField("Votre réponse", text: $writtenAnswer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...6)
                .submitLabel(.done)
                .onSubmit { submitWrittenAnswer() }

            Button("Valider", systemImage: "checkmark") { submitWrittenAnswer() }
                .buttonStyle(.borderedProminent)
                .disabled(writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
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
                    Text("\(session.correctCount) bonne\(session.correctCount > 1 ? "s" : "") réponse\(session.correctCount > 1 ? "s" : "") sur \(session.answers.count)")
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
                        session.retryErrors()
                        writtenAnswer = ""
                    }
                }
                Button("Terminer", systemImage: "checkmark") { dismiss() }
            }
        }
        .navigationTitle("Résultats")
    }

    private func answerReview(_ record: TestAnswerRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                record.isCorrect ? "Correct" : "À revoir",
                systemImage: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(record.isCorrect ? .green : .red)
            .font(.headline)

            Text(record.question.prompt)
                .font(.headline)
            Text("Votre réponse : \(record.givenAnswer)")
            Text("Bonne réponse : \(record.question.correctAnswer)")
                .foregroundStyle(.secondary)
            if record.question.type == .trueFalse {
                Text("Association correcte : \(record.question.referenceAnswer)")
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

    private func submitWrittenAnswer() {
        let cleanAnswer = writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAnswer.isEmpty else { return }
        submit(cleanAnswer)
    }

    private func submit(_ answer: String) {
        guard let record = session.submit(answer: answer),
              let card = deck.cards.first(where: { $0.id == record.question.cardID }) else { return }
        card.timesStudied += 1
        if record.isCorrect {
            card.timesCorrect += 1
        }
        deck.updatedAt = .now
        try? modelContext.save()
        writtenAnswer = ""
    }

    private func override(_ record: TestAnswerRecord) {
        guard let cardID = session.overrideWrittenAnswer(questionID: record.id),
              let card = deck.cards.first(where: { $0.id == cardID }) else { return }
        card.timesCorrect += 1
        deck.updatedAt = .now
        try? modelContext.save()
    }
}
