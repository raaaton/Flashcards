import SwiftData
import SwiftUI

struct FolderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.updatedAt, order: .reverse) private var allDecks: [Deck]

    let folder: Folder?

    @State private var searchText = ""
    @State private var showingNewDeck = false
    @State private var showingEditFolder = false
    @State private var confirmingFolderDeletion = false
    @State private var deckToEdit: Deck?
    @State private var deckToDelete: Deck?

    private var decks: [Deck] {
        let scoped = allDecks.filter { deck in
            if let folder {
                deck.folder?.id == folder.id
            } else {
                deck.folder == nil
            }
        }

        guard !searchText.isEmpty else { return scoped }
        return scoped.filter { deck in
            deck.name.localizedCaseInsensitiveContains(searchText)
                || (deck.deckDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
                || deck.cards.contains { card in
                    card.term.localizedCaseInsensitiveContains(searchText)
                        || card.definition.localizedCaseInsensitiveContains(searchText)
                }
        }
    }

    var body: some View {
        Group {
            if decks.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "Aucun deck",
                    systemImage: folder?.iconName ?? "tray",
                    description: Text("Ajoutez un deck pour commencer à organiser vos cartes.")
                )
            } else if decks.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(decks) { deck in
                        deckLink(deck)
                    }
                }
                .animation(.default, value: decks.map(\.id))
            }
        }
        .navigationTitle(folder?.name ?? L10n.text("folder.unfiled"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Decks et cartes")
        .searchToolbarBehavior(.minimize)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if let folder {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Modifier", systemImage: "pencil") { showingEditFolder = true }
                            .foregroundStyle(Theme.accent)
                        Button("Dupliquer", systemImage: "plus.square.on.square") {
                            LibraryActions.duplicateFolder(folder, in: modelContext)
                        }
                        .foregroundStyle(Theme.accent)
                        Button(role: .destructive) {
                            confirmingFolderDeletion = true
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis")
                            .foregroundStyle(.white)
                    }
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button {
                    showingNewDeck = true
                } label: {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Nouveau deck")
                .accessibilityHint("Créer un nouveau deck dans ce dossier")
            }
        }
        .sheet(isPresented: $showingNewDeck) {
            DeckFormView(initialFolder: folder)
        }
        .sheet(isPresented: $showingEditFolder) {
            if let folder {
                FolderFormView(folder: folder)
            }
        }
        .sheet(item: $deckToEdit) { deck in
            DeckFormView(deck: deck)
        }
        .alert("Supprimer ce deck ?", isPresented: deckDeleteBinding) {
            Button("Supprimer", role: .destructive) { deletePendingDeck() }
            Button("Annuler", role: .cancel) { deckToDelete = nil }
        } message: {
            Text("Toutes ses cartes seront supprimées définitivement.")
        }
        .confirmationDialog(
            "Supprimer ce dossier ?",
            isPresented: $confirmingFolderDeletion,
            titleVisibility: .visible
        ) {
            Button("Conserver les decks") { deleteFolderKeepingDecks() }
            Button("Tout supprimer", role: .destructive) { deleteFolderWithDecks() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Vous pouvez déplacer les decks vers « Sans dossier » ou supprimer définitivement tout le contenu.")
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
            Button { LibraryActions.duplicateDeck(deck, in: modelContext) } label: {
                Label("Dupliquer", systemImage: "plus.square.on.square")
                    .foregroundStyle(.white)
            }
            .tint(Theme.accent)
        }
        .contextMenu {
            Button("Modifier", systemImage: "pencil") { deckToEdit = deck }
                .foregroundStyle(Theme.accent)
            Button("Dupliquer", systemImage: "plus.square.on.square") {
                LibraryActions.duplicateDeck(deck, in: modelContext)
            }
            .foregroundStyle(Theme.accent)
            Button(role: .destructive) { deckToDelete = deck } label: {
                Label("Supprimer", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }

    private var deckDeleteBinding: Binding<Bool> {
        Binding(
            get: { deckToDelete != nil },
            set: { if !$0 { deckToDelete = nil } }
        )
    }

    private func deletePendingDeck() {
        guard let deck = deckToDelete else { return }
        modelContext.delete(deck)
        try? modelContext.save()
        deckToDelete = nil
    }

    private func deleteFolderKeepingDecks() {
        guard let folder else { return }
        LibraryActions.deleteFolderKeepingDecks(folder, in: modelContext)
        dismiss()
    }

    private func deleteFolderWithDecks() {
        guard let folder else { return }
        modelContext.delete(folder)
        try? modelContext.save()
        dismiss()
    }
}
