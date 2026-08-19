import SwiftData
import SwiftUI

struct StudyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: Deck
    let sessionNumber: Int

    @State private var session: StudySessionState
    @State private var isFlipped = false
    @State private var flipAngle = 0.0
    @State private var dragOffset: CGSize = .zero
    @State private var activeOpacity = 1.0
    @State private var isCommitting = false
    @State private var didCrossThreshold = false
    @State private var didRecordCompletion = false
    @State private var didCelebrate = false
    @State private var showCelebration = false
    @State private var confirmingReset = false

    init(
        deck: Deck,
        direction: StudyDirection,
        shuffle: Bool,
        sessionNumber: Int
    ) {
        self.deck = deck
        self.sessionNumber = sessionNumber
        let cards = deck.cards
            .filter { !$0.mastered }
            .sorted { $0.position < $1.position }
            .map { StudyCardSnapshot(id: $0.id, term: $0.term, definition: $0.definition) }
        _session = State(
            initialValue: StudySessionState(cards: cards, direction: direction, shuffle: shuffle)
        )
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
                Button("Retour", systemImage: "chevron.left") { dismiss() }
                    .foregroundStyle(.white)
                    .accessibilityHint("La progression déjà enregistrée sera conservée")
            }
        }
        .alert("Réinitialiser la progression ?", isPresented: $confirmingReset) {
            Button("Réinitialiser", role: .destructive) { resetProgress() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les cartes de ce deck redeviendront non maîtrisées.")
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
                    .buttonStyle(.glassProminent)
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
        VStack(spacing: 10) {
            HStack {
                Text(L10n.format("study.session.number", Int64(sessionNumber)))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(session.masteredInSession) / \(session.totalCards)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(session.masteredInSession),
                total: Double(max(session.totalCards, 1))
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.22),
                value: session.masteredInSession
            )
            .accessibilityLabel("Progression de la session")
            .accessibilityValue(
                L10n.format(
                    "study.progress.value",
                    Int64(session.masteredInSession),
                    Int64(session.totalCards)
                )
            )
        }
    }

    private func cardStack(exitDistance: CGFloat) -> some View {
        let visibleItems = Array(session.visibleItems.enumerated()).reversed()

        return ZStack {
            ForEach(visibleItems, id: \.element.id) { entry in
                let isActive = entry.offset == 0

                card(entry.element, isActive: isActive, exitDistance: exitDistance)
                    .id(entry.element.id)
                    .scaleEffect(
                        isActive || isCommitting ? 1 : StudyAnimationMetrics.stackScale
                    )
                    .offset(
                        y: isActive || isCommitting ? 0 : StudyAnimationMetrics.stackOffset
                    )
                    .opacity(
                        isActive ? activeOpacity : (isCommitting ? 1 : StudyAnimationMetrics.stackOpacity)
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
    }

    private func card(
        _ item: StudySessionItem,
        isActive: Bool,
        exitDistance: CGFloat
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

            if reduceMotion {
                Text(isActive && isFlipped ? item.back : item.front)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .padding(30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentTransition(.opacity)
            } else {
                StudyCardFace(
                    front: item.front,
                    back: item.back,
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
                .disabled(isCommitting)

                Button {
                    commit(.knew, predictedWidth: exitDistance, exitDistance: exitDistance)
                } label: {
                    Label("Je savais", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .disabled(isCommitting)
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
                .foregroundStyle(Theme.accent)
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

            Button(
                "Réinitialiser la progression du deck",
                systemImage: "trash",
                role: .destructive
            ) {
                confirmingReset = true
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
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

    private var summaryMessage: String {
        if remainingDeckCards == 0 {
            return L10n.text("study.all_mastered")
        }
        return L10n.format("study.cards_remaining", Int64(remainingDeckCards))
    }

    private func flipCard() {
        guard !isCommitting else { return }
        HapticService.play(.flip)
        isFlipped.toggle()
        let targetAngle = isFlipped ? 180.0 : 0.0

        withAnimation(
            reduceMotion
                ? .easeInOut(duration: 0.12)
                : .easeInOut(duration: StudyAnimationMetrics.flipDuration)
        ) {
            flipAngle = targetAngle
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

        card.timesStudied += 1
        if outcome == .knew {
            card.timesCorrect += 1
            card.mastered = true
        }

        _ = session.answer(outcome)
        if session.isComplete && !didRecordCompletion {
            didRecordCompletion = true
            if deck.cards.allSatisfy(\.mastered) {
                celebrateCompletion()
            }
        }
        deck.updatedAt = .now
        try? modelContext.save()

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isFlipped = false
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

    private func celebrateCompletion() {
        guard !didCelebrate else { return }
        didCelebrate = true
        HapticService.play(.completion)
        showCelebration = AppPreferences.celebrationsEnabled && !reduceMotion
    }
}
