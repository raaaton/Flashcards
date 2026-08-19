import SwiftData
import SwiftUI

struct DeckFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]

    let deck: Deck?
    @State private var name: String
    @State private var deckDescription: String
    @State private var selectedFolderID: UUID?

    init(deck: Deck? = nil, initialFolder: Folder? = nil) {
        self.deck = deck
        _name = State(initialValue: deck?.name ?? "")
        _deckDescription = State(initialValue: deck?.deckDescription ?? "")
        _selectedFolderID = State(initialValue: deck?.folder?.id ?? initialFolder?.id)
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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
            }
            .navigationTitle(
                deck == nil
                    ? L10n.text("deck.new.title")
                    : L10n.text("deck.edit.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(cleanName.isEmpty)
                }
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
            let newDeck = Deck(name: cleanName, folder: selectedFolder)
            newDeck.deckDescription = cleanDescription.isEmpty ? nil : cleanDescription
            modelContext.insert(newDeck)
        }
        try? modelContext.save()
        dismiss()
    }
}
