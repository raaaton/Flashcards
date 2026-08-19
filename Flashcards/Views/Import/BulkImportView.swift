import SwiftData
import SwiftUI

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

    init(
        deck: Deck? = nil,
        onDraftImport: (([ParsedCard]) -> Void)? = nil
    ) {
        draftImportHandler = onDraftImport
        _destination = State(initialValue: deck == nil ? .newDeck : .existingDeck)
        _selectedDeckID = State(initialValue: deck?.id)
    }

    init(onDraftImport: @escaping ([ParsedCard]) -> Void) {
        self.init(deck: nil, onDraftImport: onDraftImport)
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Texte à importer") {
                    TextEditor(text: $sourceText)
                        .font(.body.monospaced())
                        .frame(minHeight: 220)
                        .accessibilityLabel("Texte brut à importer")
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
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        importCards()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    }
                    .disabled(!canImport)
                    .accessibilityLabel(
                        L10n.format("import.action.cards", Int64(preview.cards.count))
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
                    Text(card.term).font(.headline)
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
            if !preview.invalidRecords.isEmpty {
                Text("Les lignes signalées seront ignorées ; les autres seront importées.")
            }
        }
    }

    private func importCards() {
        guard canImport else { return }

        if let draftImportHandler {
            draftImportHandler(preview.cards)
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
        for (offset, parsedCard) in preview.cards.enumerated() {
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
}
