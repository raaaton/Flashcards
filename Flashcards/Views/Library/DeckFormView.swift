import Foundation
import SwiftData
import SwiftUI
import UIKit

private struct DeckCardDraft: Identifiable {
    let id = UUID()
    var term: String
    var definition: String

    init(term: String = "", definition: String = "") {
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

private enum NewDeckCreationStep {
    case name
    case method
    case ai
    case manual
    case aiPreview
}

struct DeckFormView: View {
    let deck: Deck?
    let initialFolder: Folder?

    init(deck: Deck? = nil, initialFolder: Folder? = nil) {
        self.deck = deck
        self.initialFolder = initialFolder
    }

    var body: some View {
        if let deck {
            DeckEditorForm(deck: deck)
        } else {
            NewDeckCreationFlow(initialFolder: initialFolder)
        }
    }
}

private struct NewDeckCreationFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let initialFolder: Folder?

    @State private var step = NewDeckCreationStep.name
    @State private var name = ""
    @State private var selectedProvider = ExternalAIProvider.chatGPT
    @State private var importedCards: [ParsedCard] = []
    @State private var hasOpenedProvider = false
    @State private var promptWasCopied = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @FocusState private var nameFieldFocused: Bool

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            switch step {
            case .name:
                nameStep
            case .method:
                methodStep
            case .ai:
                aiStep
            case .manual:
                DeckEditorForm(
                    initialFolder: initialFolder,
                    initialName: cleanName
                )
            case .aiPreview:
                DeckEditorForm(
                    initialFolder: initialFolder,
                    initialName: cleanName,
                    initialCards: importedCards
                )
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var nameStep: some View {
        NavigationStack {
            Form {
                Section("Deck") {
                    TextField("Nom", text: $name)
                        .focused($nameFieldFocused)
                }

                Section {
                    Button {
                        guard !cleanName.isEmpty else { return }
                        HapticService.play(.selection)
                        step = .method
                    } label: {
                        Text(L10n.text("ai.continue"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(cleanName.isEmpty)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(L10n.text("deck.new.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(120))
                nameFieldFocused = true
            }
        }
    }

    private var methodStep: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("ai.creation.method.title"))
                            .font(.title2.bold())
                        Text(cleanName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    creationChoice(
                        title: L10n.text("ai.create.with_ai"),
                        subtitle: L10n.text("ai.recommended"),
                        systemImage: "sparkles",
                        isRecommended: true
                    ) {
                        hasOpenedProvider = false
                        promptWasCopied = false
                        step = .ai
                    }

                    creationChoice(
                        title: L10n.text("ai.create.manual"),
                        subtitle: nil,
                        systemImage: "square.and.pencil",
                        isRecommended: false
                    ) {
                        step = .manual
                    }
                }
                .padding(20)
            }
            .navigationTitle(L10n.text("deck.new.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("ai.back")) {
                        step = .name
                    }
                    .tint(.white)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }
            }
        }
    }

    private var aiStep: some View {
        NavigationStack {
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

                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            L10n.format("ai.instructions.title", selectedProvider.displayName),
                            systemImage: "doc.on.clipboard"
                        )
                        .font(.headline)

                        Text(
                            L10n.format(
                                "ai.instructions.body",
                                selectedProvider.displayName
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

                    if hasOpenedProvider {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(
                                L10n.format(
                                    "ai.return.title",
                                    selectedProvider.displayName
                                )
                            )
                            .font(.headline)

                            Text(
                                L10n.format(
                                    "ai.return.body",
                                    selectedProvider.displayName
                                )
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            Button {
                                pasteAIResult()
                            } label: {
                                Label(
                                    L10n.format(
                                        "ai.paste",
                                        selectedProvider.displayName
                                    ),
                                    systemImage: "doc.on.clipboard.fill"
                                )
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 32)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)

                            Button {
                                openSelectedProvider()
                            } label: {
                                Label(
                                    L10n.format(
                                        "ai.open_again",
                                        selectedProvider.displayName
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
                        Button {
                            openSelectedProvider()
                        } label: {
                            Label(
                                L10n.format(
                                    "ai.open",
                                    selectedProvider.displayName
                                ),
                                systemImage: "arrow.up.right.square"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    }

                    Button {
                        copyPrompt()
                    } label: {
                        Label(
                            promptWasCopied
                                ? L10n.text("ai.prompt_copied")
                                : L10n.text("ai.copy_prompt"),
                            systemImage: promptWasCopied
                                ? "checkmark.circle.fill"
                                : "doc.on.doc"
                        )
                        .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(promptWasCopied ? Theme.accent : .white)

                    Button {
                        openSelectedProviderWeb()
                    } label: {
                        Label(
                            L10n.format("ai.open_web", selectedProvider.displayName),
                            systemImage: "safari"
                        )
                        .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding(20)
            }
            .navigationTitle(L10n.text("ai.create.with_ai"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("ai.back")) {
                        step = .method
                    }
                    .tint(.white)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }
            }
        }
        .onAppear {
            copyPrompt(playsHaptic: false)
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
            HapticService.play(.selection)
            selectedProvider = provider
            hasOpenedProvider = false
            promptWasCopied = false
            copyPrompt(playsHaptic: false)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                NeutralIconBadge(
                    systemName: provider.systemImage,
                    size: 42,
                    cornerRadius: 13,
                    symbolSize: 17
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(provider.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if provider.isRecommended {
                            Text(L10n.text("ai.recommended"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    if provider == .chatGPT {
                        Text(L10n.text("ai.chatgpt.free_note"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                Image(
                    systemName: selectedProvider == provider
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    selectedProvider == provider
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
                        selectedProvider == provider
                            ? Theme.accent.opacity(0.55)
                            : Theme.subtleStroke,
                        lineWidth: selectedProvider == provider ? 1 : 0.5
                    )
            }
            .contentShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func copyPrompt(playsHaptic: Bool = true) {
        UIPasteboard.general.string = ExternalAIFlashcardPromptBuilder.makePrompt(
            deckName: cleanName
        )
        promptWasCopied = true
        if playsHaptic {
            HapticService.play(.selection)
        }
    }

    private func openSelectedProvider() {
        let prompt = ExternalAIFlashcardPromptBuilder.makePrompt(deckName: cleanName)
        UIPasteboard.general.string = prompt
        promptWasCopied = true
        hasOpenedProvider = false
        HapticService.play(.selection)

        openNativeProvider(
            selectedProvider.nativeLaunchCandidates(for: prompt),
            at: 0
        )
    }

    private func openNativeProvider(_ candidates: [URL], at index: Int) {
        guard candidates.indices.contains(index) else {
            showAlert(
                title: L10n.format(
                    "ai.error.app_not_installed_title",
                    selectedProvider.displayName
                ),
                message: L10n.format(
                    "ai.error.app_not_installed_body",
                    selectedProvider.displayName
                )
            )
            return
        }

        openURL(candidates[index]) { accepted in
            if accepted {
                hasOpenedProvider = true
            } else {
                openNativeProvider(candidates, at: index + 1)
            }
        }
    }

    private func openSelectedProviderWeb() {
        copyPrompt(playsHaptic: false)
        HapticService.play(.selection)
        hasOpenedProvider = true
        openURL(selectedProvider.webURL)
    }

    private func pasteAIResult() {
        guard let clipboardText = UIPasteboard.general.string,
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(
                title: L10n.text("ai.error.clipboard_title"),
                message: L10n.text("ai.error.clipboard_body")
            )
            return
        }

        do {
            importedCards = try ExternalAIFlashcardParser.parse(clipboardText)
            HapticService.play(.selection)
            step = .aiPreview
        } catch let error as ExternalAIFlashcardParserError {
            switch error {
            case .emptyResult:
                showAlert(
                    title: L10n.text("ai.error.empty_title"),
                    message: L10n.text("ai.error.empty_body")
                )
            case .invalidJSON, .incompleteRecord:
                showAlert(
                    title: L10n.text("ai.error.invalid_title"),
                    message: L10n.text("ai.error.invalid_body")
                )
            }
        } catch {
            showAlert(
                title: L10n.text("ai.error.invalid_title"),
                message: L10n.text("ai.error.invalid_body")
            )
        }
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
    private let shouldFocusName: Bool
    @State private var name: String
    @State private var selectedFolderID: UUID?
    @State private var cardDrafts: [DeckCardDraft]
    @State private var showingBulkAdd = false
    @State private var showingDuplicateChoice = false
    @FocusState private var nameFieldFocused: Bool

    init(
        deck: Deck? = nil,
        initialFolder: Folder? = nil,
        initialName: String = "",
        initialCards: [ParsedCard] = []
    ) {
        self.deck = deck
        shouldFocusName = deck == nil
            && initialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        _name = State(initialValue: deck?.name ?? initialName)
        _selectedFolderID = State(initialValue: deck?.folder?.id ?? initialFolder?.id)
        _cardDrafts = State(
            initialValue: deck == nil
                ? (initialCards.isEmpty
                    ? [DeckCardDraft()]
                    : initialCards.map {
                        DeckCardDraft(term: $0.term, definition: $0.definition)
                    })
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
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
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
            .alert(L10n.text("Doublons détectés"), isPresented: $showingDuplicateChoice) {
                if duplicateAnalysis.exactCount > 0 {
                    Button(L10n.text("Ignorer les doublons exacts")) {
                        save(skipExactDuplicates: true)
                    }
                }

                Button(L10n.text("duplicate.action.create_anyway")) {
                    save(skipExactDuplicates: false)
                }

                Button("Annuler", role: .cancel) {}
            } message: {
                Text(duplicateAlertMessage)
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
        let selectedFolder = folders.first { $0.id == selectedFolderID }

        if let deck {
            deck.name = cleanName
            deck.folder = selectedFolder
            deck.updatedAt = .now
        } else {
            guard canSave else { return }
            let newDeck = Deck(name: cleanName, folder: selectedFolder)
            modelContext.insert(newDeck)

            let draftsToSave = cardDrafts.enumerated().compactMap { index, draft -> DeckCardDraft? in
                guard draft.isComplete else { return nil }
                if skipExactDuplicates,
                   duplicateAnalysis.exactRecordIndexes.contains(index) {
                    return nil
                }
                return draft
            }

            for (position, draft) in draftsToSave.enumerated() {
                let card = Card(
                    term: draft.cleanTerm,
                    definition: draft.cleanDefinition,
                    position: position
                )
                card.deck = newDeck
                modelContext.insert(card)
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private func removeDraft(_ id: UUID) {
        withAnimation(.snappy(duration: 0.28)) {
            cardDrafts.removeAll { $0.id == id }
        }
    }
}
