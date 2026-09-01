import Foundation
import SwiftData
import SwiftUI
import UIKit

private struct DeckCardDraft: Identifiable {
    let id: UUID
    var term: String
    var definition: String

    init(id: UUID = UUID(), term: String = "", definition: String = "") {
        self.id = id
        self.term = term
        self.definition = definition
    }

    var cleanTerm: String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanDefinition: String {
        definition.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool { cleanTerm.isEmpty && cleanDefinition.isEmpty }
    var isComplete: Bool { !cleanTerm.isEmpty && !cleanDefinition.isEmpty }
}

private enum FlashcardCreationMethod: Hashable {
    case ai
    case manual
}

private enum ExternalAICreationRequest: Hashable {
    case flashcardsOnly
    case flashcardsAndTests
    case testsOnly
}

private enum NewDeckCreationStep: Hashable {
    case flashcardMethod
    case testMethod
    case ai(ExternalAICreationRequest)
    case cards
    case tests
}

private struct NewDeckDraft {
    var name = ""
    var selectedFolderID: UUID?
    var flashcardMethod: FlashcardCreationMethod?
    var testMethod: DeckTestCreationMode?
    var selectedProvider = ExternalAIProvider.gemini
    var cards = [DeckCardDraft()]
    var testConfiguration = DeckTestConfiguration.useFlashcards
    var activeAIRequest = ExternalAICreationRequest.flashcardsOnly
    var hasOpenedProvider = false
    var promptWasCopied = false

    init(initialFolderID: UUID?) {
        selectedFolderID = initialFolderID
    }
}

private struct DeckCreationStepFade: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible: Bool

    init(initiallyVisible: Bool = false) {
        _isVisible = State(initialValue: initiallyVisible)
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : (reduceMotion ? 0.88 : 0.94))
            .onAppear {
                guard !isVisible else { return }
                withAnimation(.easeOut(duration: reduceMotion ? 0.14 : 0.20)) {
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

private extension View {
    func deckCreationStepFade(initiallyVisible: Bool = false) -> some View {
        modifier(DeckCreationStepFade(initiallyVisible: initiallyVisible))
    }
}

private extension ExternalAIProvider {
    var logoAssetName: String {
        switch self {
        case .gemini: "ProviderGemini"
        case .claude: "ProviderClaude"
        case .chatGPT: "ProviderChatGPT"
        }
    }
}

private struct AIProviderLogoBadge: View {
    let provider: ExternalAIProvider

    var body: some View {
        Image(provider.logoAssetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .frame(width: 42, height: 42)
            .background(
                Theme.iconSurface,
                in: .rect(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Theme.subtleStroke, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

private struct DeckCreationBackButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.play(.selection)
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
        }
        .tint(.white)
        .accessibilityLabel(L10n.text("ai.back"))
    }
}

struct DeckFormView: View {
    let deck: Deck?
    let initialFolder: Folder?
    let onCreated: ((Deck) -> Void)?

    init(
        deck: Deck? = nil,
        initialFolder: Folder? = nil,
        onCreated: ((Deck) -> Void)? = nil
    ) {
        self.deck = deck
        self.initialFolder = initialFolder
        self.onCreated = onCreated
    }

    var body: some View {
        if let deck {
            DeckEditorForm(deck: deck)
        } else {
            NewDeckCreationFlow(
                initialFolder: initialFolder,
                onCreated: onCreated
            )
        }
    }
}

private struct NewDeckCreationFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]

    let initialFolder: Folder?
    let onCreated: ((Deck) -> Void)?

    @State private var path: [NewDeckCreationStep] = []
    @State private var draft: NewDeckDraft
    @State private var hasCompletedCreation = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @FocusState private var nameFieldFocused: Bool

    init(initialFolder: Folder?, onCreated: ((Deck) -> Void)?) {
        self.initialFolder = initialFolder
        self.onCreated = onCreated
        _draft = State(initialValue: NewDeckDraft(initialFolderID: initialFolder?.id))
    }

    private var cleanName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedFolder: Folder? {
        folders.first { $0.id == draft.selectedFolderID }
            ?? (initialFolder?.id == draft.selectedFolderID ? initialFolder : nil)
    }

    private var completeCardDrafts: [DeckCardDraft] {
        draft.cards.filter(\.isComplete)
    }

    private var sourceCards: [ExternalAISourceCard] {
        completeCardDrafts.map {
            ExternalAISourceCard(id: $0.id, term: $0.cleanTerm, definition: $0.cleanDefinition)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            nameStep
                .deckCreationStepFade(initiallyVisible: true)
                .navigationDestination(for: NewDeckCreationStep.self) { destination in
                    destinationView(destination)
                        .deckCreationStepFade()
                }
        }
        .background {
            Color.clear
                .alert(alertTitle, isPresented: $showingAlert) {
                    Button("OK", role: .cancel) {}
                        .normalActionColor()
                } message: {
                    Text(alertMessage)
                }
                .tint(.white)
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: NewDeckCreationStep) -> some View {
        switch destination {
        case .flashcardMethod:
            flashcardMethodStep
        case .testMethod:
            testMethodStep
        case let .ai(request):
            aiStep(request)
        case .cards:
            DeckEditorForm(
                initialFolder: selectedFolder,
                initialName: cleanName,
                initialDrafts: draft.cards,
                onBack: returnFromCardEditor,
                onDraftsCompleted: completeCardEditing,
                embedsInNavigationStack: false,
                dismissesOnSave: false
            )
        case .tests:
            AuthoredTestsEditor(
                sourceCards: sourceCards,
                configuration: draft.testConfiguration,
                onBack: { configuration in
                    draft.testConfiguration = configuration
                    navigateBack()
                },
                onComplete: { configuration in
                    draft.testConfiguration = configuration
                    createDeck()
                }
            )
        }
    }

    private var nameStep: some View {
        Form {
            Section("Deck") {
                TextField("Nom", text: $draft.name)
                    .focused($nameFieldFocused)
                    .submitLabel(.continue)
                    .onSubmit(advanceFromName)
            }
        }
        .navigationTitle(L10n.text("deck.new.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
                    .tint(.white)
            }

            ToolbarItem(placement: .confirmationAction) {
                CircularSaveButton(
                    accent: Theme.accent,
                    isEnabled: !cleanName.isEmpty
                ) {
                    advanceFromName()
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(120))
            nameFieldFocused = true
        }
    }

    private var flashcardMethodStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.text("ai.creation.method.title"))
                    .font(.title2.bold())

                creationChoice(
                    title: L10n.text("ai.create.with_ai"),
                    subtitle: L10n.text("ai.recommended"),
                    systemImage: "sparkles",
                    isRecommended: true
                ) {
                    draft.flashcardMethod = .ai
                    navigateForward(to: .testMethod)
                }

                creationChoice(
                    title: L10n.text("ai.create.manual"),
                    subtitle: nil,
                    systemImage: "square.and.pencil",
                    isRecommended: false
                ) {
                    draft.flashcardMethod = .manual
                    navigateForward(to: .testMethod)
                }
            }
            .padding(20)
        }
        .navigationTitle(L10n.text("deck.new.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DeckCreationBackButton {
                    navigateBack()
                }
            }
        }
    }

    private var testMethodStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.text("ai.creation.test_method.title"))
                    .font(.title2.bold())

                creationChoice(
                    title: L10n.text("ai.create.with_ai"),
                    subtitle: L10n.text("ai.recommended"),
                    systemImage: "sparkles",
                    isRecommended: true
                ) {
                    selectTestMethod(.ai)
                }

                creationChoice(
                    title: L10n.text("ai.test.use_flashcards"),
                    subtitle: nil,
                    systemImage: "rectangle.stack",
                    isRecommended: false
                ) {
                    selectTestMethod(.useFlashcards)
                }

                creationChoice(
                    title: L10n.text("ai.create.manual"),
                    subtitle: nil,
                    systemImage: "square.and.pencil",
                    isRecommended: false
                ) {
                    selectTestMethod(.manual)
                }
            }
            .padding(20)
        }
        .navigationTitle(L10n.text("deck.new.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DeckCreationBackButton {
                    navigateBack()
                }
            }
        }
    }

    private func aiStep(_ request: ExternalAICreationRequest) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("ai.provider.title"))
                        .font(.title2.bold())
                    Text(L10n.text("ai.provider.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(ExternalAIProvider.allCases) { provider in
                        providerRow(provider)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            aiBottomPanel(request)
        }
        .navigationTitle(L10n.text("ai.create.with_ai"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DeckCreationBackButton {
                    navigateBack()
                }
            }
        }
        .onAppear {
            if draft.activeAIRequest != request {
                draft.activeAIRequest = request
                draft.hasOpenedProvider = false
                draft.promptWasCopied = false
            }
            guard !draft.promptWasCopied else { return }
            copyPrompt(for: request, playsHaptic: false)
        }
    }

    @ViewBuilder
    private func aiBottomPanel(_ request: ExternalAICreationRequest) -> some View {
        VStack(spacing: 12) {
            if draft.hasOpenedProvider {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        L10n.format(
                            "ai.return.title",
                            draft.selectedProvider.displayName
                        )
                    )
                    .font(.headline)

                    Text(
                        L10n.format(
                            returnBodyKey(for: request),
                            draft.selectedProvider.displayName
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Button {
                        pasteAIResult(for: request)
                    } label: {
                        Label(
                            L10n.format(
                                "ai.paste",
                                draft.selectedProvider.displayName
                            ),
                            systemImage: "doc.on.clipboard.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(Theme.foreground(on: Theme.accent))
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

                    Button {
                        openSelectedProvider(for: request)
                    } label: {
                        Label(
                            L10n.format(
                                "ai.open_again",
                                draft.selectedProvider.displayName
                            ),
                            systemImage: "arrow.up.right.square"
                        )
                        .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding(16)
                .background(
                    Theme.cardBackground,
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        L10n.format("ai.instructions.title", draft.selectedProvider.displayName),
                        systemImage: "doc.on.clipboard"
                    )
                    .font(.headline)

                    Text(
                        L10n.format(
                            "ai.instructions.body",
                            draft.selectedProvider.displayName
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    Theme.cardBackground,
                    in: .rect(cornerRadius: 18, style: .continuous)
                )

                Button {
                    openSelectedProvider(for: request)
                } label: {
                    Label(
                        L10n.format(
                            "ai.open",
                            draft.selectedProvider.displayName
                        ),
                        systemImage: "arrow.up.right.square"
                    )
                    .font(.headline)
                    .foregroundStyle(Theme.foreground(on: Theme.accent))
                    .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func advanceFromName() {
        guard !cleanName.isEmpty else { return }
        HapticService.play(.selection)
        nameFieldFocused = false
        navigateForward(to: .flashcardMethod)
    }

    private func selectTestMethod(_ method: DeckTestCreationMode) {
        draft.testMethod = method
        draft.testConfiguration.mode = method
        draft.hasOpenedProvider = false
        draft.promptWasCopied = false

        if draft.flashcardMethod == .ai {
            let request: ExternalAICreationRequest = method == .ai
                ? .flashcardsAndTests
                : .flashcardsOnly
            draft.activeAIRequest = request
            navigateForward(to: .ai(request))
        } else {
            navigateForward(to: .cards)
        }
    }

    private func navigateForward(to destination: NewDeckCreationStep) {
        path.append(destination)
    }

    private func navigateBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    private func returnFromCardEditor(
        _ updatedName: String,
        _ folderID: UUID?,
        _ drafts: [DeckCardDraft]
    ) {
        draft.name = updatedName
        draft.selectedFolderID = folderID
        draft.cards = drafts
        navigateBack()
    }

    private func completeCardEditing(
        _ updatedName: String,
        _ folderID: UUID?,
        _ drafts: [DeckCardDraft],
        _ remappedCardIDs: [UUID: UUID]
    ) {
        draft.name = updatedName
        draft.selectedFolderID = folderID
        draft.cards = drafts
        remapTestSources(remappedCardIDs)

        switch draft.testMethod {
        case .useFlashcards:
            createDeck()
        case .manual:
            draft.testConfiguration.mode = .manual
            navigateForward(to: .tests)
        case .ai:
            draft.testConfiguration.mode = .ai
            if draft.flashcardMethod == .manual {
                draft.activeAIRequest = .testsOnly
                draft.hasOpenedProvider = false
                draft.promptWasCopied = false
                navigateForward(to: .ai(.testsOnly))
            } else {
                navigateForward(to: .tests)
            }
        case nil:
            break
        }
    }

    private func creationChoice(
        title: String,
        subtitle: String?,
        systemImage: String,
        isRecommended: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticService.play(.selection)
            action()
        } label: {
            HStack(spacing: 14) {
                NeutralIconBadge(
                    systemName: systemImage,
                    size: 46,
                    cornerRadius: 15,
                    symbolSize: 19
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isRecommended ? Theme.accent : .secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                Theme.cardBackground,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isRecommended ? Theme.accent.opacity(0.35) : Theme.subtleStroke,
                        lineWidth: 0.75
                    )
            }
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func providerRow(_ provider: ExternalAIProvider) -> some View {
        Button {
            guard draft.selectedProvider != provider else { return }
            HapticService.play(.selection)
            draft.selectedProvider = provider
            draft.hasOpenedProvider = false
            draft.promptWasCopied = false
            copyPrompt(for: draft.activeAIRequest, playsHaptic: false)
        } label: {
            HStack(spacing: 14) {
                AIProviderLogoBadge(provider: provider)

                Text(provider.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(
                    systemName: draft.selectedProvider == provider
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    draft.selectedProvider == provider
                        ? Theme.accent
                        : Color.secondary
                )
            }
            .padding(15)
            .background(
                Theme.cardBackground,
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        draft.selectedProvider == provider
                            ? Theme.accent.opacity(0.55)
                            : Theme.subtleStroke,
                        lineWidth: draft.selectedProvider == provider ? 1 : 0.5
                    )
            }
            .contentShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func copyPrompt(
        for request: ExternalAICreationRequest,
        playsHaptic: Bool = true
    ) {
        UIPasteboard.general.string = prompt(for: request)
        draft.promptWasCopied = true
        if playsHaptic {
            HapticService.play(.selection)
        }
    }

    private func openSelectedProvider(for request: ExternalAICreationRequest) {
        let prompt = prompt(for: request)
        UIPasteboard.general.string = prompt
        draft.promptWasCopied = true
        draft.hasOpenedProvider = false
        HapticService.play(.selection)

        openNativeProvider(
            draft.selectedProvider.nativeLaunchCandidates(for: prompt),
            at: 0
        )
    }

    private func openNativeProvider(_ candidates: [URL], at index: Int) {
        guard candidates.indices.contains(index) else {
            showAlert(
                title: L10n.format(
                    "ai.error.app_not_installed_title",
                    draft.selectedProvider.displayName
                ),
                message: L10n.format(
                    "ai.error.app_not_installed_body",
                    draft.selectedProvider.displayName
                )
            )
            return
        }

        openURL(candidates[index]) { accepted in
            if accepted {
                draft.hasOpenedProvider = true
            } else {
                openNativeProvider(candidates, at: index + 1)
            }
        }
    }

    private func pasteAIResult(for request: ExternalAICreationRequest) {
        guard let clipboardText = UIPasteboard.general.string,
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(
                title: L10n.text("ai.error.clipboard_title"),
                message: L10n.text("ai.error.clipboard_body")
            )
            return
        }

        do {
            switch request {
            case .flashcardsOnly:
                let parsedCards = try ExternalAIFlashcardParser.parse(clipboardText)
                draft.cards = parsedCards.map {
                    DeckCardDraft(term: $0.term, definition: $0.definition)
                }
                navigateForward(to: .cards)
            case .flashcardsAndTests:
                let imported = try ExternalAIAuthoredParser.parseCombined(clipboardText)
                draft.cards = imported.cards.map {
                    DeckCardDraft(id: $0.id, term: $0.term, definition: $0.definition)
                }
                draft.testConfiguration = imported.testConfiguration
                navigateForward(to: .cards)
            case .testsOnly:
                draft.testConfiguration = try ExternalAIAuthoredParser.parseTestsOnly(
                    clipboardText,
                    sourceCards: sourceCards
                )
                navigateForward(to: .tests)
            }
            HapticService.play(.selection)
        } catch ExternalAIFlashcardParserError.emptyResult {
            showAlert(
                title: L10n.text("ai.error.empty_title"),
                message: L10n.text("ai.error.empty_body")
            )
        } catch {
            showAlert(
                title: L10n.text("ai.error.invalid_title"),
                message: L10n.text(
                    request == .flashcardsOnly
                        ? "ai.error.invalid_body"
                        : (request == .flashcardsAndTests
                            ? "ai.error.combined_invalid_body"
                            : "ai.error.tests_invalid_body")
                )
            )
        }
    }

    private func prompt(for request: ExternalAICreationRequest) -> String {
        switch request {
        case .flashcardsOnly:
            ExternalAIFlashcardPromptBuilder.makePrompt(deckName: cleanName)
        case .flashcardsAndTests:
            ExternalAIFlashcardPromptBuilder.makeCombinedPrompt(deckName: cleanName)
        case .testsOnly:
            ExternalAIFlashcardPromptBuilder.makeTestsOnlyPrompt(
                deckName: cleanName,
                cards: sourceCards
            )
        }
    }

    private func returnBodyKey(for request: ExternalAICreationRequest) -> String {
        switch request {
        case .flashcardsOnly: "ai.return.body"
        case .flashcardsAndTests: "ai.return.body.combined"
        case .testsOnly: "ai.return.body.tests"
        }
    }

    private func remapTestSources(_ cardIDMap: [UUID: UUID]) {
        guard !cardIDMap.isEmpty else { return }
        draft.testConfiguration.multipleChoice = draft.testConfiguration.multipleChoice.map { question in
            var copy = question
            copy.sourceCardID = cardIDMap[question.sourceCardID] ?? question.sourceCardID
            return copy
        }
        draft.testConfiguration.trueFalse = draft.testConfiguration.trueFalse.map { question in
            var copy = question
            copy.sourceCardID = cardIDMap[question.sourceCardID] ?? question.sourceCardID
            return copy
        }
    }

    private func createDeck() {
        guard !hasCompletedCreation, !cleanName.isEmpty, !completeCardDrafts.isEmpty else { return }

        let configuration: DeckTestConfiguration
        if draft.testMethod == .useFlashcards {
            configuration = .useFlashcards
        } else {
            guard let validated = try? draft.testConfiguration.validated(
                validCardIDs: Set(completeCardDrafts.map(\.id))
            ), validated.authoredQuestionCount > 0 else {
                showAlert(
                    title: L10n.text("ai.error.invalid_title"),
                    message: L10n.text("test.editor.validation_error")
                )
                return
            }
            configuration = validated
        }

        let deck = Deck(name: cleanName, folder: selectedFolder)
        modelContext.insert(deck)
        for (position, draft) in completeCardDrafts.enumerated() {
            let card = Card(
                term: draft.cleanTerm,
                definition: draft.cleanDefinition,
                position: position
            )
            card.id = draft.id
            card.deck = deck
            modelContext.insert(card)
        }
        deck.setTestConfiguration(configuration)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            showAlert(
                title: L10n.text("deck.new.save_error.title"),
                message: error.localizedDescription
            )
            return
        }

        hasCompletedCreation = true
        onCreated?(deck)
        dismiss()
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

private struct DeckEditorForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]

    let deck: Deck?
    let onBack: ((String, UUID?, [DeckCardDraft]) -> Void)?
    let onDraftsCompleted: ((String, UUID?, [DeckCardDraft], [UUID: UUID]) -> Void)?
    let embedsInNavigationStack: Bool
    let dismissesOnSave: Bool
    private let shouldFocusName: Bool
    @State private var name: String
    @State private var selectedFolderID: UUID?
    @State private var cardDrafts: [DeckCardDraft]
    @State private var showingBulkAdd = false
    @State private var showingDuplicateChoice = false
    @State private var isSaving = false
    @FocusState private var nameFieldFocused: Bool

    init(
        deck: Deck? = nil,
        initialFolder: Folder? = nil,
        initialName: String = "",
        initialDrafts: [DeckCardDraft] = [],
        onBack: ((String, UUID?, [DeckCardDraft]) -> Void)? = nil,
        onDraftsCompleted: ((String, UUID?, [DeckCardDraft], [UUID: UUID]) -> Void)? = nil,
        embedsInNavigationStack: Bool = true,
        dismissesOnSave: Bool = true
    ) {
        self.deck = deck
        self.onBack = onBack
        self.onDraftsCompleted = onDraftsCompleted
        self.embedsInNavigationStack = embedsInNavigationStack
        self.dismissesOnSave = dismissesOnSave
        shouldFocusName = deck == nil
            && initialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        _name = State(initialValue: deck?.name ?? initialName)
        _selectedFolderID = State(initialValue: deck?.folder?.id ?? initialFolder?.id)
        _cardDrafts = State(
            initialValue: deck == nil
                ? (initialDrafts.isEmpty
                    ? [DeckCardDraft()]
                    : initialDrafts)
                : []
        )
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validDrafts: [DeckCardDraft] {
        cardDrafts.filter(\.isComplete)
    }

    private var hasIncompleteDraft: Bool {
        cardDrafts.contains { !$0.isEmpty && !$0.isComplete }
    }

    private var canSave: Bool {
        guard !isSaving else { return false }
        guard !cleanName.isEmpty else { return false }
        guard deck == nil else { return true }
        return !validDrafts.isEmpty && !hasIncompleteDraft
    }

    private var controlAccent: Color {
        Theme.accent
    }

    private var duplicateAnalysis: BulkDuplicateAnalysis {
        let candidates = cardDrafts.enumerated().compactMap { index, draft -> ParsedCard? in
            guard draft.isComplete else { return nil }
            return ParsedCard(
                recordIndex: index,
                term: draft.cleanTerm,
                definition: draft.cleanDefinition
            )
        }

        return BulkDuplicateDetector.analyze(
            candidates: candidates,
            existingCards: []
        )
    }

    var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack {
                    editorContent
                }
            } else {
                editorContent
            }
        }
        .sheet(isPresented: $showingBulkAdd) {
            BulkImportView(
                comparisonCards: validDrafts.enumerated().map { index, draft in
                    ParsedCard(
                        recordIndex: index,
                        term: draft.cleanTerm,
                        definition: draft.cleanDefinition
                    )
                },
                saveAccent: controlAccent
            ) { parsedCards in
                cardDrafts.removeAll(where: \.isEmpty)
                cardDrafts.append(contentsOf: parsedCards.map {
                    DeckCardDraft(term: $0.term, definition: $0.definition)
                })
            }
        }
    }

    private var editorContent: some View {
        Form {
            Section("Deck") {
                TextField("Nom", text: $name)
                    .focused($nameFieldFocused)
                    .task {
                        guard shouldFocusName else { return }
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        nameFieldFocused = true
                    }
            }

            Section("Dossier") {
                Picker("Emplacement", selection: $selectedFolderID) {
                    Text("Sans dossier").tag(nil as UUID?)

                    ForEach(folders) { folder in
                        Text(folder.name).tag(folder.id as UUID?)
                    }
                }
                .tint(controlAccent)
            }

            if deck == nil {
                ForEach($cardDrafts) { $draft in
                    Section {
                        CardEditorSurface(
                            term: $draft.term,
                            definition: $draft.definition,
                            roundsBottomCorners: duplicateKind(for: draft.id) == nil
                        )
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 0,
                                bottom: 0,
                                trailing: 0
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: true
                        ) {
                            Button(role: .destructive) {
                                removeDraft(draft.id)
                            } label: {
                                Label(
                                    "Supprimer",
                                    systemImage: "trash"
                                )
                            }
                            .tint(.red)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                removeDraft(draft.id)
                            } label: {
                                Label(
                                    "Supprimer",
                                    systemImage: "trash"
                                )
                            }
                            .destructiveActionColor()
                        }
                        .transition(
                            .move(edge: .bottom)
                                .combined(with: .opacity)
                        )

                        if let kind = duplicateKind(for: draft.id) {
                            duplicateWarning(for: kind)
                        }
                    } header: {
                        if draft.id == cardDrafts.first?.id {
                            Text("Cartes initiales")
                        }
                    }
                    .listSectionSpacing(6)
                }

                Section {
                    Button("Ajouter une carte", systemImage: "plus") {
                        withAnimation(.snappy(duration: 0.28)) {
                            cardDrafts.append(DeckCardDraft())
                        }
                    }
                    .normalActionColor()

                    Button("Ajout en masse", systemImage: "text.badge.plus") {
                        showingBulkAdd = true
                    }
                    .normalActionColor()
                } footer: {
                    if hasIncompleteDraft {
                        Text("Chaque carte commencée doit avoir un terme et une définition.")
                            .foregroundStyle(.red)
                    } else if validDrafts.isEmpty {
                        Text("Ajoutez au moins une carte pour créer le deck.")
                    } else if duplicateAnalysis.exactCount > 0 || duplicateAnalysis.possibleCount > 0 {
                        Text(duplicateAlertMessage)
                    }
                }
                .listSectionSpacing(12)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(
            deck == nil
                ? L10n.text("deck.new.title")
                : L10n.text("deck.edit.title")
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onBack != nil)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    DeckCreationBackButton {
                        onBack(cleanName, selectedFolderID, cardDrafts)
                    }
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                CircularSaveButton(
                    accent: controlAccent,
                    isEnabled: canSave
                ) {
                    prepareSave()
                }
            }
        }
        .background {
            Color.clear
                .alert(L10n.text("Doublons détectés"), isPresented: $showingDuplicateChoice) {
                    if duplicateAnalysis.exactCount > 0 {
                        Button(L10n.text("Ignorer les doublons exacts")) {
                            save(skipExactDuplicates: true)
                        }
                        .normalActionColor()
                    }

                    Button(L10n.text("duplicate.action.create_anyway")) {
                        save(skipExactDuplicates: false)
                    }
                    .normalActionColor()

                    Button("Annuler", role: .cancel) {}
                        .normalActionColor()
                } message: {
                    Text(duplicateAlertMessage)
                }
                .tint(.white)
        }
    }

    @ViewBuilder
    private func duplicateWarning(for kind: BulkDuplicateKind) -> some View {
        switch kind {
        case .exact:
            Label(
                L10n.text("duplicate.label.exact"),
                systemImage: "exclamationmark.octagon.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.red)
        case .possible:
            Label(
                L10n.text("duplicate.label.possible"),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
        }
    }

    private func duplicateKind(for draftID: UUID) -> BulkDuplicateKind? {
        guard let index = cardDrafts.firstIndex(where: { $0.id == draftID }) else {
            return nil
        }
        return duplicateAnalysis.kind(for: index)
    }

    private var duplicateAlertMessage: String {
        if duplicateAnalysis.exactCount > 0 && duplicateAnalysis.possibleCount > 0 {
            return L10n.format(
                "import.duplicates.both",
                Int64(duplicateAnalysis.exactCount),
                Int64(duplicateAnalysis.possibleCount)
            )
        }
        if duplicateAnalysis.possibleCount > 0 {
            return L10n.format(
                "import.duplicates.possible",
                Int64(duplicateAnalysis.possibleCount)
            )
        }
        return L10n.format(
            "import.duplicates.exact",
            Int64(duplicateAnalysis.exactCount)
        )
    }

    private func prepareSave() {
        guard canSave else { return }

        if deck == nil,
           duplicateAnalysis.exactCount > 0 || duplicateAnalysis.possibleCount > 0 {
            showingDuplicateChoice = true
        } else {
            save(skipExactDuplicates: false)
        }
    }

    private func save(skipExactDuplicates: Bool) {
        guard canSave else { return }
        isSaving = true

        let selectedFolder = folders.first { $0.id == selectedFolderID }

        if let deck {
            deck.name = cleanName
            deck.folder = selectedFolder
            deck.updatedAt = .now
        } else {
            let (draftsToSave, remappedCardIDs) = finalizedDrafts(
                skippingExactDuplicates: skipExactDuplicates
            )

            if let onDraftsCompleted {
                isSaving = false
                onDraftsCompleted(
                    cleanName,
                    selectedFolderID,
                    draftsToSave,
                    remappedCardIDs
                )
                return
            }

            let newDeck = Deck(name: cleanName, folder: selectedFolder)
            modelContext.insert(newDeck)

            for (position, draft) in draftsToSave.enumerated() {
                let card = Card(
                    term: draft.cleanTerm,
                    definition: draft.cleanDefinition,
                    position: position
                )
                card.id = draft.id
                card.deck = newDeck
                modelContext.insert(card)
            }
        }

        do {
            try modelContext.save()
        } catch {
            isSaving = false
            return
        }

        if dismissesOnSave {
            dismiss()
        }
    }

    private func finalizedDrafts(
        skippingExactDuplicates: Bool
    ) -> ([DeckCardDraft], [UUID: UUID]) {
        let indexedDrafts = cardDrafts.enumerated().filter { $0.element.isComplete }
        guard skippingExactDuplicates else {
            return (indexedDrafts.map(\.element), [:])
        }

        var firstDraftIDByContent: [String: UUID] = [:]
        var keptDrafts: [DeckCardDraft] = []
        var remappedCardIDs: [UUID: UUID] = [:]

        for (index, draft) in indexedDrafts {
            let key = [
                BulkDuplicateDetector.normalizedValue(draft.cleanTerm),
                BulkDuplicateDetector.normalizedValue(draft.cleanDefinition)
            ].joined(separator: "\u{1F}")

            if duplicateAnalysis.exactRecordIndexes.contains(index),
               let keptID = firstDraftIDByContent[key] {
                remappedCardIDs[draft.id] = keptID
            } else {
                firstDraftIDByContent[key] = draft.id
                keptDrafts.append(draft)
            }
        }
        return (keptDrafts, remappedCardIDs)
    }

    private func removeDraft(_ id: UUID) {
        withAnimation(.snappy(duration: 0.28)) {
            cardDrafts.removeAll { $0.id == id }
        }
    }
}
