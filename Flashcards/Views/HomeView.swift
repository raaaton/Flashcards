import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.createdAt) private var folders: [Folder]
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    @State private var searchText = ""
    @State private var showingNewFolder = false
    @State private var showingNewDeck = false
    @State private var showingBulkImport = false
    @State private var folderToRename: Folder?
    @State private var folderToDelete: Folder?
    @State private var deckToEdit: Deck?
    @State private var deckToDelete: Deck?

    private var matchingDecks: [Deck] {
        guard !searchText.isEmpty else { return decks }
        return decks.filter { deck in
            deck.name.localizedCaseInsensitiveContains(searchText)
                || (deck.deckDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
                || deck.cards.contains { card in
                    card.term.localizedCaseInsensitiveContains(searchText)
                        || card.definition.localizedCaseInsensitiveContains(searchText)
                }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty && folders.isEmpty {
                    ContentUnavailableView(
                        "Aucun deck",
                        systemImage: "rectangle.stack",
                        description: Text("Créez votre premier deck pour commencer à réviser.")
                    )
                } else if matchingDecks.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    libraryList
                }
            }
            .navigationTitle("Flashcards")
            .searchable(text: $searchText, prompt: "Decks et cartes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Nouveau deck", systemImage: "rectangle.stack.badge.plus") {
                            showingNewDeck = true
                        }
                        Button("Nouveau dossier", systemImage: "folder.badge.plus") {
                            showingNewFolder = true
                        }
                        Divider()
                        Button("Importer en masse", systemImage: "text.badge.plus") {
                            showingBulkImport = true
                        }
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                    .accessibilityHint("Créer un deck ou un dossier")
                }
            }
        }
        .sheet(isPresented: $showingNewFolder) {
            FolderFormView()
        }
        .sheet(isPresented: $showingNewDeck) {
            DeckFormView()
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView()
        }
        .sheet(item: $folderToRename) { folder in
            FolderFormView(folder: folder)
        }
        .sheet(item: $deckToEdit) { deck in
            DeckFormView(deck: deck)
        }
        .confirmationDialog(
            "Supprimer ce dossier ?",
            isPresented: folderDeleteBinding,
            titleVisibility: .visible
        ) {
            Button("Conserver les decks") { deleteFolderKeepingDecks() }
            Button("Tout supprimer", role: .destructive) { deleteFolderWithDecks() }
            Button("Annuler", role: .cancel) { folderToDelete = nil }
        } message: {
            Text("Vous pouvez déplacer les decks vers « Sans dossier » ou supprimer définitivement tout le contenu.")
        }
        .alert("Supprimer ce deck ?", isPresented: deckDeleteBinding) {
            Button("Supprimer", role: .destructive) { deletePendingDeck() }
            Button("Annuler", role: .cancel) { deckToDelete = nil }
        } message: {
            Text("Toutes ses cartes seront supprimées définitivement.")
        }
    }

    private var libraryList: some View {
        List {
            ForEach(folders) { folder in
                let sectionDecks = matchingDecks.filter { $0.folder?.id == folder.id }
                if !sectionDecks.isEmpty || searchText.isEmpty {
                    Section {
                        if sectionDecks.isEmpty {
                            Text("Aucun deck")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(sectionDecks) { deck in
                                deckLink(deck)
                            }
                        }
                    } header: {
                        folderHeader(folder)
                    }
                }
            }

            let orphanedDecks = matchingDecks.filter { $0.folder == nil }
            if !orphanedDecks.isEmpty {
                Section("Sans dossier") {
                    ForEach(orphanedDecks) { deck in
                        deckLink(deck)
                    }
                }
            }
        }
        .animation(.default, value: matchingDecks.map(\.id))
    }

    private func folderHeader(_ folder: Folder) -> some View {
        HStack {
            Label(folder.name, systemImage: "folder")
            Spacer()
            Menu {
                Button("Renommer", systemImage: "pencil") { folderToRename = folder }
                Button("Supprimer", systemImage: "trash", role: .destructive) {
                    folderToDelete = folder
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Actions pour le dossier \(folder.name)")
            }
        }
    }

    private func deckLink(_ deck: Deck) -> some View {
        NavigationLink {
            DeckDetailView(deck: deck)
        } label: {
            DeckRow(deck: deck)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deckToDelete = deck } label: {
                Label("Supprimer", systemImage: "trash")
            }
            Button { duplicate(deck) } label: {
                Label("Dupliquer", systemImage: "plus.square.on.square")
            }
            .tint(Theme.accent)
        }
        .contextMenu {
            Button("Modifier", systemImage: "pencil") { deckToEdit = deck }
            Button("Dupliquer", systemImage: "plus.square.on.square") { duplicate(deck) }
            Button("Supprimer", systemImage: "trash", role: .destructive) { deckToDelete = deck }
        }
    }

    private var folderDeleteBinding: Binding<Bool> {
        Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        )
    }

    private var deckDeleteBinding: Binding<Bool> {
        Binding(
            get: { deckToDelete != nil },
            set: { if !$0 { deckToDelete = nil } }
        )
    }

    private func duplicate(_ source: Deck) {
        let copy = Deck(name: "\(source.name) — copie", folder: source.folder)
        copy.deckDescription = source.deckDescription
        modelContext.insert(copy)

        for sourceCard in source.cards.sorted(by: { $0.position < $1.position }) {
            let card = Card(
                term: sourceCard.term,
                definition: sourceCard.definition,
                position: sourceCard.position
            )
            card.deck = copy
            modelContext.insert(card)
        }
        try? modelContext.save()
    }

    private func deleteFolderKeepingDecks() {
        guard let folder = folderToDelete else { return }
        for deck in Array(folder.decks) {
            deck.folder = nil
            deck.updatedAt = .now
        }
        modelContext.delete(folder)
        try? modelContext.save()
        folderToDelete = nil
    }

    private func deleteFolderWithDecks() {
        guard let folder = folderToDelete else { return }
        modelContext.delete(folder)
        try? modelContext.save()
        folderToDelete = nil
    }

    private func deletePendingDeck() {
        guard let deck = deckToDelete else { return }
        modelContext.delete(deck)
        try? modelContext.save()
        deckToDelete = nil
    }
}
