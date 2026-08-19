import SwiftData
import SwiftUI

struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck
    @State private var session: StudySessionState
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var confirmingReset = false

    init(deck: Deck, direction: StudyDirection, includeMastered: Bool) {
        self.deck = deck
        let cards = deck.cards
            .filter { includeMastered || !$0.mastered }
            .sorted { $0.position < $1.position }
            .map { StudyCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition) }
        _session = State(initialValue: StudySessionState(cards: cards, direction: direction))
    }

    var body: some View {
        Group {
            if session.isComplete {
                summary
            } else {
                studyContent
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Quitter", systemImage: "xmark") { dismiss() }
                    .accessibilityHint("La progression déjà enregistrée sera conservée")
            }
        }
        .alert("Réinitialiser la progression ?", isPresented: $confirmingReset) {
            Button("Réinitialiser", role: .destructive) { resetProgress() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les cartes de ce deck redeviendront non maîtrisées.")
        }
    }

    private var studyContent: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Round \(session.roundNumber)", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                Text("\(session.remainingInRound) restante\(session.remainingInRound > 1 ? "s" : "")")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))

            if let item = session.currentItem {
                flashcard(item)
                    .frame(maxHeight: .infinity)
            }

            if isFlipped {
                answerControls
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button("Afficher la réponse", systemImage: "arrow.2.circlepath") {
                    flipCard()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func flashcard(_ item: StudyRoundItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

            Text(item.front)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(30)
                .opacity(isFlipped ? 0 : 1)

            Text(item.back)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(30)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.7
        )
        .offset(dragOffset)
        .rotationEffect(.degrees(Double(dragOffset.width / 25)))
        .contentShape(.rect)
        .onTapGesture { flipCard() }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard isFlipped else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    guard isFlipped else { return }
                    if value.translation.width > 90 {
                        answer(.knew)
                    } else if value.translation.width < -90 {
                        answer(.review)
                    } else {
                        withAnimation(.spring) { dragOffset = .zero }
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFlipped ? "Réponse : \(item.back)" : "Question : \(item.front)")
        .accessibilityHint("Touchez deux fois pour retourner la carte")
        .accessibilityAction { flipCard() }
    }

    private var answerControls: some View {
        HStack(spacing: 14) {
            Button {
                answer(.review)
            } label: {
                Label("À revoir", systemImage: "arrow.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button {
                answer(.knew)
            } label: {
                Label("Je savais", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.accent)
            Text("Session terminée")
                .font(.largeTitle.bold())
            Text("Toutes les cartes de cette session sont maîtrisées.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 28) {
                statistic(value: "\(session.cardsSeen)", label: "Cartes vues")
                statistic(value: "\(session.successRate) %", label: "Réussite")
            }

            Spacer()

            Button("Recommencer la session", systemImage: "arrow.counterclockwise") {
                restartAllCards()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Réinitialiser la progression du deck", systemImage: "trash", role: .destructive) {
                confirmingReset = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statistic(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func flipCard() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            isFlipped.toggle()
        }
    }

    private func answer(_ outcome: StudyOutcome) {
        guard let cardID = session.currentItem?.id,
              let card = deck.cards.first(where: { $0.id == cardID }) else { return }

        card.timesStudied += 1
        if case .knew = outcome {
            card.timesCorrect += 1
            card.mastered = true
        }
        deck.updatedAt = .now
        try? modelContext.save()

        withAnimation(.spring) {
            _ = session.answer(outcome)
            isFlipped = false
            dragOffset = .zero
        }
    }

    private func restartAllCards() {
        let cards = deck.cards
            .sorted { $0.position < $1.position }
            .map { StudyCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition) }
        session.restart(with: cards)
        isFlipped = false
        dragOffset = .zero
    }

    private func resetProgress() {
        for card in deck.cards {
            card.mastered = false
        }
        deck.updatedAt = .now
        try? modelContext.save()
        restartAllCards()
    }
}
