import SwiftData
import SwiftUI

struct StudyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck

    @State private var sessionNumber: Int
    @State private var session: StudySessionState
    @State private var isFlipped = false
    @State private var isFlipAnimating = false
    @State private var flipAngle = 0.0
    @State private var dragOffset: CGSize = .zero
    @State private var activeOpacity = 1.0
    @State private var isCommitting = false
    @State private var didCrossThreshold = false
    @State private var didRecordCompletion = false
    @State private var didCelebrate = false
    @State private var showCelebration = false
    @State private var confirmingReset = false
    @State private var cardToEdit: Card?

    init(deck: Deck, snapshot: ActiveStudySessionSnapshot) {
        self.deck = deck
        _sessionNumber = State(initialValue: snapshot.sessionNumber)
        _session = State(initialValue: snapshot.state)
    }

    private var accent: Color { Theme.deckAccent(for: deck) }

    var body: some View {
        Group {
            if session.isComplete {
                summary
            } else {
                studyContent
            }
        }
        .navigationBarBackButtonHidden()
        .tint(accent)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .neutralIconColor()
                }
                    .tint(.white)
                    .accessibilityLabel("Retour")
                    .accessibilityHint("La progression déjà enregistrée sera conservée")
            }

            if !session.isComplete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard !isCommitting, let card = currentDeckCard else { return }
                        HapticService.play(.selection)
                        cardToEdit = card
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .neutralIconColor()
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                    .disabled(isCommitting || currentDeckCard == nil)
                    .accessibilityLabel(L10n.text("card.edit.title"))
                }
            }
        }
        .sheet(item: $cardToEdit) { card in
            CardFormView(deck: deck, card: card) {
                refreshCurrentCard(from: card)
            }
        }
        .background {
            Color.clear
                .alert("Réinitialiser la progression ?", isPresented: $confirmingReset) {
                    Button("Réinitialiser", role: .destructive) { resetProgress() }
                    Button("Annuler", role: .cancel) {}
                        .normalActionColor()
                } message: {
                    Text("Toutes les cartes de ce deck redeviendront non maîtrisées.")
                }
                .tint(.white)
        }
        .overlay {
            if showCelebration {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
    }

    private var studyContent: some View {
        GeometryReader { proxy in
            let exitDistance = max(proxy.size.width * 1.45, 520)

            VStack(spacing: 18) {
                sessionHeader

                cardStack(exitDistance: exitDistance)
                    .frame(maxHeight: .infinity)

                if isFlipped {
                    answerControls(exitDistance: exitDistance)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button("Afficher la réponse", systemImage: "arrow.2.circlepath") {
                        flipCard()
                    }
                    .buttonStyle(.glass)
                    .tint(.clear)
                    .foregroundStyle(.white)
                    .disabled(isCommitting)
                }
            }
            .padding()
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L10n.format("study.session.number", Int64(sessionNumber)))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    undoLastJudgment()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .neutralIconColor()
                }
                .buttonStyle(.plain)
                .tint(.white)
                .disabled(!session.canUndo || isCommitting)
                .accessibilityLabel("study.undo")

                Text("\(session.cardsSeen) / \(session.totalCards)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                sessionCounter(
                    label: L10n.text("study.incorrect"),
                    value: session.reviewAnswers,
                    color: .red,
                    alignment: .leading
                )
                Spacer()
                sessionCounter(
                    label: L10n.text("study.correct"),
                    value: session.correctAnswers,
                    color: .green,
                    alignment: .trailing
                )
            }

            ProgressView(
                value: Double(session.cardsSeen),
                total: Double(max(session.totalCards, 1))
            )
            .tint(.white.opacity(0.65))
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.22),
                value: session.cardsSeen
            )
            .accessibilityLabel("Progression de la session")
            .accessibilityValue(
                L10n.format(
                    "study.progress.value",
                    Int64(session.cardsSeen),
                    Int64(session.totalCards)
                )
            )
        }
    }

    private func sessionCounter(
        label: String,
        value: Int,
        color: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }

    private func cardStack(exitDistance: CGFloat) -> some View {
        let visibleItems = Array(session.visibleItems.enumerated()).reversed()

        return ZStack {
            ForEach(visibleItems, id: \.element.id) { entry in
                let isActive = entry.offset == 0

                card(entry.element, isActive: isActive, exitDistance: exitDistance)
                    .id(entry.element.id)
                    .scaleEffect(
                        stackScale(isActive: isActive)
                    )
                    .offset(
                        y: stackOffset(isActive: isActive)
                    )
                    .opacity(
                        stackOpacity(isActive: isActive)
                    )
                    .zIndex(isActive ? 1 : 0)
                    .allowsHitTesting(isActive && !isCommitting)
            }
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(
                    response: StudyAnimationMetrics.transitionResponse,
                    dampingFraction: StudyAnimationMetrics.transitionDamping
                ),
            value: isCommitting
        )
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: StudyAnimationMetrics.flipDuration * 0.55),
            value: isFlipAnimating
        )
    }

    private func stackScale(isActive: Bool) -> CGFloat {
        guard !isActive, !isCommitting else { return 1 }
        return isFlipAnimating
            ? StudyAnimationMetrics.flippingStackScale
            : StudyAnimationMetrics.stackScale
    }

    private func stackOffset(isActive: Bool) -> CGFloat {
        guard !isActive, !isCommitting else { return 0 }
        return isFlipAnimating
            ? StudyAnimationMetrics.flippingStackOffset
            : StudyAnimationMetrics.stackOffset
    }

    private func stackOpacity(isActive: Bool) -> Double {
        if isActive { return activeOpacity }
        if isCommitting { return 1 }
        return isFlipAnimating
            ? StudyAnimationMetrics.flippingStackOpacity
            : StudyAnimationMetrics.stackOpacity
    }

    private func card(
        _ item: StudySessionItem,
        isActive: Bool,
        exitDistance: CGFloat
    ) -> some View {
        ZStack {
            if reduceMotion {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Theme.cardBackground)
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                    Text(isActive && isFlipped ? item.back : item.front)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.72)
                        .padding(30)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentTransition(.opacity)
                }
            } else {
                StudyCardFace(
                    front: item.front,
                    back: item.back,
                    obscuresContent: !isActive && isFlipAnimating,
                    angle: isActive ? flipAngle : 0
                )
            }

            if isActive {
                swipeFeedback
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .offset(isActive ? dragOffset : .zero)
        .rotationEffect(.degrees(isActive && !reduceMotion ? cardRotation : 0))
        .rotation3DEffect(
            .degrees(isActive && !reduceMotion ? cardTilt : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.45
        )
        .contentShape(.rect)
        .onTapGesture {
            guard isActive else { return }
            flipCard()
        }
        .gesture(isActive ? dragGesture(exitDistance: exitDistance) : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isActive && isFlipped
                ? L10n.format("study.accessibility.answer", item.back)
                : L10n.format("study.accessibility.question", item.front)
        )
        .accessibilityHint("Touchez deux fois pour retourner la carte, ou utilisez les actions d’étude")
        .accessibilityAction { if isActive { flipCard() } }
        .accessibilityAction(named: "Je savais") {
            if isActive { commit(.knew, predictedWidth: exitDistance, exitDistance: exitDistance) }
        }
        .accessibilityAction(named: "À revoir") {
            if isActive { commit(.review, predictedWidth: -exitDistance, exitDistance: exitDistance) }
        }
    }

    private var swipeFeedback: some View {
        let isKnew = dragOffset.width >= 0
        let color = isKnew ? Color.green : Color.red
        let progress = swipeProgress

        return ZStack(alignment: isKnew ? .topLeading : .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(color.opacity(progress * 0.2))

            Image(systemName: isKnew ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(color)
                .padding(24)
                .opacity(progress)
                .scaleEffect(0.82 + progress * 0.18)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var swipeProgress: Double {
        Double(min(abs(dragOffset.width) / StudyAnimationMetrics.swipeThreshold, 1))
    }

    private var cardRotation: Double {
        let normalized = max(-1, min(1, dragOffset.width / StudyAnimationMetrics.swipeThreshold))
        return Double(normalized) * StudyAnimationMetrics.maxCardRotation
    }

    private var cardTilt: Double {
        let normalized = max(-1, min(1, dragOffset.width / StudyAnimationMetrics.swipeThreshold))
        return -Double(normalized) * StudyAnimationMetrics.maxCardTilt
    }

    private func dragGesture(exitDistance: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isCommitting else { return }
                dragOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height * 0.12
                )

                if abs(value.translation.width) >= StudyAnimationMetrics.swipeThreshold,
                   !didCrossThreshold {
                    didCrossThreshold = true
                    HapticService.play(value.translation.width >= 0 ? .correct : .review)
                }
            }
            .onEnded { value in
                guard !isCommitting else { return }
                let actualWidth = value.translation.width
                let predictedWidth = value.predictedEndTranslation.width
                let passedThreshold = abs(actualWidth) >= StudyAnimationMetrics.swipeThreshold
                    || abs(predictedWidth) >= StudyAnimationMetrics.swipeThreshold * 1.15

                if passedThreshold {
                    let directionWidth = abs(predictedWidth) > abs(actualWidth)
                        ? predictedWidth
                        : actualWidth
                    commit(
                        directionWidth >= 0 ? .knew : .review,
                        predictedWidth: directionWidth,
                        exitDistance: exitDistance
                    )
                } else {
                    didCrossThreshold = false
                    withAnimation(
                        .spring(
                            response: StudyAnimationMetrics.returnResponse,
                            dampingFraction: StudyAnimationMetrics.returnDamping
                        )
                    ) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func answerControls(exitDistance: CGFloat) -> some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    commit(.review, predictedWidth: -exitDistance, exitDistance: exitDistance)
                } label: {
                    Label("À revoir", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .allowsHitTesting(!isCommitting)

                Button {
                    commit(.knew, predictedWidth: exitDistance, exitDistance: exitDistance)
                } label: {
                    Label("Je savais", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .allowsHitTesting(!isCommitting)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(
                systemName: remainingDeckCards == 0
                    ? "checkmark.circle.fill"
                    : "clock.arrow.circlepath"
            )
                .font(.system(size: 72))
                .foregroundStyle(accent)
            Text(L10n.format("study.session.complete", Int64(sessionNumber)))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(summaryMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 28) {
                statistic(value: "\(session.cardsSeen)", label: L10n.text("study.cards_seen"))
                statistic(value: "\(session.successRate) %", label: L10n.text("study.success_rate"))
            }

            Spacer()

            Button("Terminer", systemImage: "checkmark") {
                dismiss()
            }
            .foregroundStyle(.white)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !session.reviewedCardIDs.isEmpty {
                Button("study.review_mistakes", systemImage: "arrow.counterclockwise") {
                    startReviewMistakes()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button(role: .destructive) {
                confirmingReset = true
            } label: {
                Label("Réinitialiser la progression du deck", systemImage: "trash")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Theme.cardBackground,
                        in: .rect(cornerRadius: 14, style: .continuous)
                    )
                    .contentShape(.rect)
            }
            .destructiveActionColor()
            .buttonStyle(.plain)
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

    private var remainingDeckCards: Int {
        deck.cards.count { !$0.mastered }
    }

    private var currentDeckCard: Card? {
        guard let cardID = session.currentItem?.id else { return nil }
        return deck.cards.first { $0.id == cardID }
    }

    private var summaryMessage: String {
        if remainingDeckCards == 0 {
            return L10n.text("study.all_mastered")
        }
        return L10n.format("study.cards_remaining", Int64(remainingDeckCards))
    }

    private func flipCard() {
        guard !isCommitting, !isFlipAnimating else { return }
        HapticService.play(.flip)
        isFlipAnimating = !reduceMotion
        isFlipped.toggle()
        let targetAngle = isFlipped ? 180.0 : 0.0

        withAnimation(
            reduceMotion
                ? .easeInOut(duration: 0.12)
                : .easeInOut(duration: StudyAnimationMetrics.flipDuration)
        ) {
            flipAngle = targetAngle
        }

        guard !reduceMotion else { return }
        Task { @MainActor in
            try? await Task.sleep(
                for: .milliseconds(Int(StudyAnimationMetrics.flipDuration * 1_000))
            )
            isFlipAnimating = false
        }
    }

    private func commit(
        _ outcome: StudyOutcome,
        predictedWidth: CGFloat,
        exitDistance: CGFloat
    ) {
        guard !isCommitting,
              let cardID = session.currentItem?.id else { return }

        if !didCrossThreshold {
            HapticService.play(outcome == .knew ? .correct : .review)
        }
        isCommitting = true
        let sign: CGFloat = outcome == .knew ? 1 : -1
        let inertialDistance = max(exitDistance, abs(predictedWidth) * 1.12)

        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(
                    response: StudyAnimationMetrics.transitionResponse,
                    dampingFraction: StudyAnimationMetrics.transitionDamping
                )
        ) {
            if reduceMotion {
                activeOpacity = 0
            } else {
                dragOffset = CGSize(width: sign * inertialDistance, height: dragOffset.height * 0.45)
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(StudyAnimationMetrics.commitMilliseconds))
            finalize(outcome, cardID: cardID)
        }
    }

    private func finalize(_ outcome: StudyOutcome, cardID: UUID) {
        guard isCommitting,
              session.currentItem?.id == cardID,
              let card = deck.cards.first(where: { $0.id == cardID }) else { return }

        let previousProgress = StudyCardProgressSnapshot(
            mastered: card.mastered,
            timesStudied: card.timesStudied,
            timesCorrect: card.timesCorrect
        )
        card.timesStudied += 1
        if outcome == .knew {
            card.timesCorrect += 1
            card.mastered = true
        }

        _ = session.answer(outcome, previousProgress: previousProgress)
        if session.isComplete && !didRecordCompletion {
            didRecordCompletion = true
            deck.completedStudySessions = sessionNumber
            deck.activeStudySessionData = nil
            deck.recordCompletedSession(
                mode: .flashcards,
                itemCount: session.cardsSeen,
                correctCount: session.correctAnswers,
                incorrectCount: session.reviewAnswers
            )
            if deck.cards.allSatisfy(\.mastered) {
                celebrateCompletion()
            }
        } else if !session.isComplete {
            persistActiveSession()
        }
        deck.lastStudyActivityAt = .now
        deck.updatedAt = .now
        try? modelContext.save()

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isFlipped = false
            isFlipAnimating = false
            flipAngle = 0
            dragOffset = .zero
            activeOpacity = 1
            didCrossThreshold = false
            isCommitting = false
        }
    }

    private func resetProgress() {
        LibraryActions.resetStudyProgress(for: deck, in: modelContext)
        dismiss()
    }

    private func persistActiveSession() {
        let snapshot = ActiveStudySessionSnapshot(
            deckID: deck.id,
            sessionNumber: sessionNumber,
            state: session
        )
        deck.activeStudySessionData = try? StudySessionPersistence.encode(snapshot)
    }

    private func refreshCurrentCard(from card: Card) {
        guard session.currentItem?.id == card.id,
              session.updateCard(
                  id: card.id,
                  term: card.term,
                  definition: card.definition
              ) else { return }

        if deck.activeStudySessionData != nil {
            persistActiveSession()
            try? modelContext.save()
        }
    }

    private func undoLastJudgment() {
        guard !isCommitting else { return }
        var undoneJudgment: StudyJudgment?
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(response: 0.32, dampingFraction: 0.82)
        ) {
            undoneJudgment = session.undoLastAnswer()
        }
        guard let judgment = undoneJudgment,
              let card = deck.cards.first(where: { $0.id == judgment.cardID }) else { return }

        card.mastered = judgment.previousProgress.mastered
        card.timesStudied = judgment.previousProgress.timesStudied
        card.timesCorrect = judgment.previousProgress.timesCorrect
        isFlipped = false
        isFlipAnimating = false
        flipAngle = 0
        dragOffset = .zero
        activeOpacity = 1
        didCrossThreshold = false
        deck.lastStudyActivityAt = .now
        deck.updatedAt = .now

        if session.currentIndex > 0 {
            persistActiveSession()
        } else {
            deck.activeStudySessionData = nil
        }

        try? modelContext.save()
        HapticService.play(.selection)
    }

    private func startReviewMistakes() {
        let reviewedIDs = session.reviewedCardIDs
        let cardsByID = Dictionary(uniqueKeysWithValues: deck.cards.map { ($0.id, $0) })
        let cards = reviewedIDs.compactMap { id -> StudyCardSnapshot? in
            guard let card = cardsByID[id] else { return nil }
            return StudyCardSnapshot(id: card.id, term: card.term, definition: card.definition)
        }
        guard !cards.isEmpty else { return }

        sessionNumber = deck.completedStudySessions + 1
        session = StudySessionState(
            cards: cards,
            direction: session.direction,
            shuffle: session.shuffle,
            sessionSize: .all,
            starredOnly: session.starredOnly ?? false
        )
        didRecordCompletion = false
        didCelebrate = false
        showCelebration = false
        isFlipped = false
        flipAngle = 0
        dragOffset = .zero
        activeOpacity = 1
        deck.activeStudySessionData = nil
        deck.lastStudyActivityAt = .now
        deck.updatedAt = .now
        try? modelContext.save()
        HapticService.play(.selection)
    }

    private func celebrateCompletion() {
        guard !didCelebrate else { return }
        didCelebrate = true
        HapticService.play(.completion)
        showCelebration = AppPreferences.celebrationsEnabled && !reduceMotion
    }
}
