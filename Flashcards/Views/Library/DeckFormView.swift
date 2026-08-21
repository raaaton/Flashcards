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
    @State private var deckDescription: String
    @State private var selectedFolderID: UUID?
    @State private var cardDrafts: [DeckCardDraft]
    @State private var showingBulkAdd = false

    init(deck: Deck? = nil, initialFolder: Folder? = nil) {
        self.deck = deck
        _name = State(initialValue: deck?.name ?? "")
        _deckDescription = State(initialValue: deck?.deckDescription ?? "")
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

    private var accent: Color {
        folders
            .first(where: { $0.id == selectedFolderID })
            .map { Color(folderHex: $0.colorHex) }
            ?? Theme.accent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck") {
                    TextField("Nom", text: $name)
                    TextField("Description (facultative)", text: $deckDescription, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Dossier") {
                    Picker("Emplacement", selection: $selectedFolderID) {
                        Text("Sans dossier").tag(nil as UUID?)
                        ForEach(folders) { folder in
                            Text(folder.name).tag(folder.id as UUID?)
                        }
                    }
                }

                if deck == nil {
                    Section {
                        ForEach($cardDrafts) { $draft in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label(
                                        "Carte",
                                        systemImage: "rectangle"
                                    )
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                    Spacer()

                                    Button(role: .destructive) {
                                        removeDraft(draft.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .frame(width: 32, height: 32)
                                    }
                                    .destructiveActionColor()
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Supprimer")
                                }

                                CardEditorSurface(
                                    term: $draft.term,
                                    definition: $draft.definition,
                                    accent: accent
                                )
                            }
                            .padding(.vertical, 6)
                            .listRowInsets(
                                EdgeInsets(
                                    top: 8,
                                    leading: 0,
                                    bottom: 8,
                                    trailing: 0
                                )
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        Button("Ajouter une carte", systemImage: "plus") {
                            cardDrafts.append(DeckCardDraft())
                        }
                        .normalActionColor(accent)

                        Button("Ajout en masse", systemImage: "text.badge.plus") {
                            showingBulkAdd = true
                        }
                        .normalActionColor(accent)
                    } header: {
                        Text("Cartes initiales")
                    } footer: {
                        if hasIncompleteDraft {
                            Text("Chaque carte commencée doit avoir un terme et une définition.")
                                .foregroundStyle(.red)
                        } else if validDrafts.isEmpty {
                            Text("Ajoutez au moins une carte pour créer le deck.")
                        }
                    }
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
                        accent: accent,
                        isEnabled: canSave
                    ) {
                        save()
                    }
                }
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
                saveAccent: accent
            ) { parsedCards in
                cardDrafts.removeAll(where: \.isEmpty)
                cardDrafts.append(contentsOf: parsedCards.map {
                    DeckCardDraft(term: $0.term, definition: $0.definition)
                })
            }
        }
    }

    private func save() {
        let selectedFolder = folders.first { $0.id == selectedFolderID }
        let cleanDescription = deckDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if let deck {
            deck.name = cleanName
            deck.deckDescription = cleanDescription.isEmpty ? nil : cleanDescription
            deck.folder = selectedFolder
            deck.updatedAt = .now
        } else {
            guard canSave else { return }
            let newDeck = Deck(name: cleanName, folder: selectedFolder)
            newDeck.deckDescription = cleanDescription.isEmpty ? nil : cleanDescription
            modelContext.insert(newDeck)
            for (position, draft) in validDrafts.enumerated() {
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
        cardDrafts.removeAll { $0.id == id }
    }
}
