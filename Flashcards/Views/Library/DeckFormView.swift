import Foundation
import SwiftData
import SwiftUI

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

struct DeckFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]

    let deck: Deck?
    @State private var name: String
    @State private var selectedFolderID: UUID?
    @State private var cardDrafts: [DeckCardDraft]
    @State private var showingBulkAdd = false
    @State private var showingDuplicateChoice = false
    @FocusState private var nameFieldFocused: Bool

    init(deck: Deck? = nil, initialFolder: Folder? = nil) {
        self.deck = deck
        _name = State(initialValue: deck?.name ?? "")
        _selectedFolderID = State(initialValue: deck?.folder?.id ?? initialFolder?.id)
        _cardDrafts = State(initialValue: deck == nil ? [DeckCardDraft()] : [])
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
                            guard deck == nil else { return }
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
                        .normalActionColor(controlAccent)

                        Button("Ajout en masse", systemImage: "text.badge.plus") {
                            showingBulkAdd = true
                        }
                        .normalActionColor(controlAccent)
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
