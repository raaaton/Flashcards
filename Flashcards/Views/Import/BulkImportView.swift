import SwiftData
import SwiftUI
import UIKit

private enum ImportDestination: String, CaseIterable, Identifiable {
    case newDeck
    case existingDeck

    var id: Self { self }

    var title: String {
        switch self {
        case .newDeck: L10n.text("import.destination.new_deck")
        case .existingDeck: L10n.text("import.destination.existing_deck")
        }
    }
}

struct BulkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.name) private var decks: [Deck]
    @Query(sort: \Folder.name) private var folders: [Folder]

    private let draftImportHandler: (([ParsedCard]) -> Void)?
    private let draftComparisonCards: [(term: String, definition: String)]
    private let inheritedAccent: Color?

    @State private var sourceText = ""
    @State private var termOption = TermDefinitionDelimiterOption.colon
    @State private var cardOption = CardDelimiterOption.newline
    @State private var customTermDelimiter = ""
    @State private var customCardDelimiter = ""
    @State private var preview = BulkImportResult.empty
    @State private var destination: ImportDestination
    @State private var selectedDeckID: UUID?
    @State private var newDeckName = ""
    @State private var selectedFolderID: UUID?
    @State private var showingDuplicateChoice = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false

    init(
        deck: Deck? = nil,
        comparisonCards: [ParsedCard] = [],
        saveAccent: Color? = nil,
        onDraftImport: (([ParsedCard]) -> Void)? = nil
    ) {
        draftImportHandler = onDraftImport
        draftComparisonCards = comparisonCards.map { ($0.term, $0.definition) }
        inheritedAccent = saveAccent
        _destination = State(initialValue: deck == nil ? .newDeck : .existingDeck)
        _selectedDeckID = State(initialValue: deck?.id)
    }

    init(
        comparisonCards: [ParsedCard] = [],
        saveAccent: Color? = nil,
        onDraftImport: @escaping ([ParsedCard]) -> Void
    ) {
        self.init(
            deck: nil,
            comparisonCards: comparisonCards,
            saveAccent: saveAccent,
            onDraftImport: onDraftImport
        )
    }

    private var accent: Color {
        if let inheritedAccent {
            return inheritedAccent
        }

        if destination == .existingDeck,
           let deck = decks.first(where: { $0.id == selectedDeckID }) {
            return Theme.deckAccent(for: deck)
        }

        if destination == .newDeck,
           let folder = folders.first(where: { $0.id == selectedFolderID }) {
            return Color(folderHex: folder.colorHex)
        }

        return .gray
    }

    private var termDelimiter: String {
        termOption.resolved(customValue: customTermDelimiter)
    }

    private var cardDelimiter: String {
        cardOption.resolved(customValue: customCardDelimiter)
    }

    private var parseInput: BulkImportInput {
        BulkImportInput(
            text: sourceText,
            termDelimiter: termDelimiter,
            cardDelimiter: cardDelimiter
        )
    }

    private var cleanDeckName: String {
        newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var delimitersAreValid: Bool {
        !termDelimiter.isEmpty && !cardDelimiter.isEmpty
    }

    private var destinationIsValid: Bool {
        if draftImportHandler != nil { return true }
        switch destination {
        case .newDeck: return !cleanDeckName.isEmpty
        case .existingDeck: return selectedDeckID != nil
        }
    }

    private var canImport: Bool {
        delimitersAreValid && destinationIsValid && !preview.cards.isEmpty
    }

    private var destinationCards: [(term: String, definition: String)] {
        if draftImportHandler != nil { return draftComparisonCards }
        guard destination == .existingDeck,
              let deck = decks.first(where: { $0.id == selectedDeckID }) else {
            return []
        }
        return deck.cards.map { ($0.term, $0.definition) }
    }

    private var duplicateAnalysis: BulkDuplicateAnalysis {
        BulkDuplicateDetector.analyze(
            candidates: preview.cards,
            existingCards: destinationCards
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Texte à importer") {
                    TextEditor(text: $sourceText)
                        .font(.body.monospaced())
                        .frame(minHeight: 220)
                        .accessibilityLabel("Texte brut à importer")

                    Button("Coller", systemImage: "doc.on.clipboard") {
                        pasteFromClipboard()
                    }
                    .normalActionColor()
                }

                Section("Entre terme et définition") {
                    Picker("Délimiteur", selection: $termOption) {
                        ForEach(TermDefinitionDelimiterOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if termOption == .custom {
                        TextField("Délimiteur personnalisé", text: $customTermDelimiter)
                    }
                }

                Section("Entre les cartes") {
                    Picker("Délimiteur", selection: $cardOption) {
                        ForEach(CardDelimiterOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if cardOption == .custom {
                        TextField("Délimiteur personnalisé", text: $customCardDelimiter)
                    }
                }

                if delimitersAreValid && termDelimiter == cardDelimiter {
                    Section {
                        Label(
                            "Les deux délimiteurs sont identiques, ce qui peut rendre le texte ambigu.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }
                }

                if draftImportHandler == nil {
                    destinationSection
                }
                previewSection

            }
            .navigationTitle(draftImportHandler == nil ? "Importer en masse" : "Ajout en masse")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    CircularSaveButton(
                        accent: accent,
                        isEnabled: canImport
                    ) {
                        prepareImport()
                    }
                    .accessibilityLabel(
                        L10n.format(
                            "import.action.cards",
                            Int64(preview.cards.count)
                        )
                    )
                }
            }
            .task(id: parseInput) {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                preview = BulkImportParser.parse(parseInput)
            }
            .onAppear {
                if destination == .existingDeck, selectedDeckID == nil {
                    selectedDeckID = decks.first?.id
                }
                if decks.isEmpty {
                    destination = .newDeck
                }

                if selectedFolderID == nil,
                   folders.count == 1 {
                    selectedFolderID = folders.first?.id
                }
            }
            .background {
                Color.clear
                    .alert(
                        "Doublons détectés",
                        isPresented: $showingDuplicateChoice
                    ) {
                        if duplicateAnalysis.exactCount > 0 {
                            Button("Ignorer les doublons exacts") {
                                importCards(skipExactDuplicates: true)
                            }
                            .normalActionColor()
                        }

                        Button("Importer quand même") {
                            importCards(skipExactDuplicates: false)
                        }
                        .normalActionColor()

                        Button("Annuler", role: .cancel) {}
                            .normalActionColor()
                    } message: {
                        if duplicateAnalysis.exactCount > 0 && duplicateAnalysis.possibleCount > 0 {
                            Text(
                                L10n.format(
                                    "import.duplicates.both",
                                    Int64(duplicateAnalysis.exactCount),
                                    Int64(duplicateAnalysis.possibleCount)
                                )
                            )
                        } else if duplicateAnalysis.possibleCount > 0 {
                            Text(
                                L10n.format(
                                    "import.duplicates.possible",
                                    Int64(duplicateAnalysis.possibleCount)
                                )
                            )
                        } else {
                            Text(
                                L10n.format(
                                    "import.duplicates.exact",
                                    Int64(duplicateAnalysis.exactCount)
                                )
                            )
                        }
                    }
                    .tint(.white)
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
    }

    @ViewBuilder
    private var destinationSection: some View {
        Section("Destination") {
            Picker("Destination", selection: $destination) {
                ForEach(ImportDestination.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: destination) { _, newValue in
                if newValue == .existingDeck, selectedDeckID == nil {
                    selectedDeckID = decks.first?.id
                }
            }

            if destination == .newDeck {
                TextField("Nom du nouveau deck", text: $newDeckName)
                Picker("Dossier", selection: $selectedFolderID) {
                    Text("Sans dossier").tag(nil as UUID?)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(folder.id as UUID?)
                    }
                }
            } else if decks.isEmpty {
                Text("Créez d’abord un deck ou choisissez « Nouveau deck ».")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Deck", selection: $selectedDeckID) {
                    ForEach(decks) { deck in
                        Text(deck.name).tag(deck.id as UUID?)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section {
            if sourceText.isEmpty {
                Text("Collez du texte pour afficher l’aperçu.")
                    .foregroundStyle(.secondary)
            } else if !delimitersAreValid {
                Label("Saisissez un délimiteur personnalisé non vide.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if preview.cards.isEmpty && preview.invalidRecords.isEmpty {
                Text("Aucune carte détectée.")
                    .foregroundStyle(.secondary)
            }

            ForEach(preview.cards) { card in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(card.term).font(.headline)
                        Spacer()
                        if let kind = duplicateAnalysis.kind(for: card.recordIndex) {
                            Label(
                                kind == .exact
                                    ? L10n.text("import.duplicate.exact")
                                    : L10n.text("import.duplicate.possible"),
                                systemImage: kind == .exact
                                    ? "exclamationmark.octagon.fill"
                                    : "exclamationmark.triangle.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(kind == .exact ? .red : .orange)
                        }
                    }
                    Label(card.definition, systemImage: "arrow.right")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            ForEach(preview.invalidRecords) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        L10n.format("import.preview.ignored_line", Int64(record.recordIndex + 1)),
                        systemImage: "exclamationmark.circle"
                    )
                        .font(.headline)
                    Text(record.content)
                        .lineLimit(2)
                    Text(record.reason)
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        } header: {
            Text(L10n.format("import.preview.count", Int64(preview.cards.count)))
        } footer: {
            if duplicateAnalysis.exactCount > 0 || duplicateAnalysis.possibleCount > 0 {
                Text(
                    "\(duplicateAnalysis.exactCount) doublon(s) exact(s), \(duplicateAnalysis.possibleCount) possible(s). Les doublons possibles restent toujours importés."
                )
            } else if !preview.invalidRecords.isEmpty {
                Text("Les lignes signalées seront ignorées ; les autres seront importées.")
            }
        }
    }

    private func pasteFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty else {
            showAlert(
                title: "Presse-papiers vide",
                message: "Aucun texte n’est disponible à coller."
            )
            return
        }

        let pastedResult = BulkImportParser.parse(
            BulkImportInput(
                text: clipboardText,
                termDelimiter: termDelimiter,
                cardDelimiter: cardDelimiter
            )
        )
        guard delimitersAreValid, !pastedResult.cards.isEmpty else {
            showAlert(
                title: "Texte non reconnu",
                message: "Le presse-papiers ne contient aucune carte valide avec les délimiteurs actuels. Le texte existant a été conservé."
            )
            return
        }
        sourceText = clipboardText
        preview = pastedResult
        HapticService.play(.selection)
    }

    private func prepareImport() {
        guard canImport else { return }

        if duplicateAnalysis.exactCount > 0 || duplicateAnalysis.possibleCount > 0 {
            showingDuplicateChoice = true
        } else {
            importCards(skipExactDuplicates: false)
        }
    }

    private func importCards(skipExactDuplicates: Bool) {
        guard canImport else { return }
        let cardsToImport = skipExactDuplicates
            ? preview.cards.filter {
                !duplicateAnalysis.exactRecordIndexes.contains($0.recordIndex)
            }
            : preview.cards

        guard !cardsToImport.isEmpty else {
            showAlert(
                title: "Aucune nouvelle carte",
                message: "Toutes les cartes détectées sont déjà présentes."
            )
            return
        }

        if let draftImportHandler {
            draftImportHandler(cardsToImport)
            dismiss()
            return
        }

        let targetDeck: Deck

        switch destination {
        case .newDeck:
            let folder = folders.first { $0.id == selectedFolderID }
            let deck = Deck(name: cleanDeckName, folder: folder)
            modelContext.insert(deck)
            targetDeck = deck
        case .existingDeck:
            guard let deck = decks.first(where: { $0.id == selectedDeckID }) else { return }
            targetDeck = deck
        }

        let startPosition = (targetDeck.cards.map(\.position).max() ?? -1) + 1
        for (offset, parsedCard) in cardsToImport.enumerated() {
            let card = Card(
                term: parsedCard.term,
                definition: parsedCard.definition,
                position: startPosition + offset
            )
            card.deck = targetDeck
            modelContext.insert(card)
        }
        targetDeck.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}
