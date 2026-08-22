import SwiftData
import SwiftUI

struct FolderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.updatedAt, order: .reverse) private var allDecks: [Deck]

    let folder: Folder?

    @State private var showingSearch = false
    @State private var showingNewDeck = false
    @State private var showingEditFolder = false
    @State private var confirmingFolderDeletion = false
    @State private var deckToEdit: Deck?
    @State private var deckToDelete: Deck?
    @State private var createdDeckToOpen: Deck?
    @State private var hasQueuedCreatedDeck = false
    @State private var showingCreatedDeck = false

    private var decks: [Deck] {
        let scoped = allDecks.filter { deck in
            if let folder {
                deck.folder?.id == folder.id
            } else {
                deck.folder == nil
            }
        }

        return scoped
    }

    var body: some View {
        Group {
            if decks.isEmpty {
                ContentUnavailableView(
                    "Aucun deck",
                    systemImage: folder?.iconName ?? "tray",
                    description: Text("Ajoutez un deck pour commencer à organiser vos cartes.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(decks) { deck in
                            deckTileLink(deck)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
                .animation(.spring(duration: 0.35), value: decks.map(\.id))
            }
        }
        .navigationTitle(folder?.name ?? L10n.text("folder.unfiled"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showingCreatedDeck) {
            if let createdDeckToOpen {
                DeckDetailView(deck: createdDeckToOpen)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .neutralIconColor()
                }
                .tint(.white)
                .accessibilityLabel("Rechercher")

                if let folder {
                    Menu {
                        Button("Modifier", systemImage: "pencil") { showingEditFolder = true }
                            .normalActionColor()
                        Button("Dupliquer", systemImage: "plus.square.on.square") {
                            LibraryActions.duplicateFolder(folder, in: modelContext)
                        }
                        .normalActionColor()
                        Button(role: .destructive) {
                            confirmingFolderDeletion = true
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                        .destructiveActionColor()
                    } label: {
                        Image(systemName: "ellipsis")
                            .neutralIconColor()
                    }
                    .tint(.white)
                    .accessibilityLabel("Actions")
                }
            }

        }
        .concentricFloatingAction {
            Button {
                showingNewDeck = true
            } label: {
                Image(systemName: "plus")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 72, height: 72)
                    .glassEffect(
                        .regular.interactive(),
                        in: .circle
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nouveau deck")
            .accessibilityHint("Créer un nouveau deck dans ce dossier")
        }
        .sheet(
            isPresented: $showingNewDeck,
            onDismiss: openCreatedDeckIfNeeded
        ) {
            DeckFormView(
                initialFolder: folder,
                onCreated: queueCreatedDeck
            )
        }
        .sheet(isPresented: $showingSearch) {
            DeckSearchView(decks: decks, showsFolderContext: false)
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
                .normalActionColor()
        } message: {
            Text("Toutes ses cartes seront supprimées définitivement.")
        }
        .confirmationDialog(
            "Supprimer ce dossier ?",
            isPresented: $confirmingFolderDeletion,
            titleVisibility: .visible
        ) {
            Button("Conserver les decks") { deleteFolderKeepingDecks() }
                .normalActionColor()
            Button("Tout supprimer", role: .destructive) { deleteFolderWithDecks() }
            Button("Annuler", role: .cancel) {}
                .normalActionColor()
        } message: {
            Text("Vous pouvez déplacer les decks vers « Sans dossier » ou supprimer définitivement tout le contenu.")
        }
    }

    private func deckTileLink(_ deck: Deck) -> some View {
        NavigationLink {
            DeckDetailView(deck: deck)
        } label: {
            DeckTile(deck: deck)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(
                deck.isPinned ? "Désépingler" : "Épingler",
                systemImage: deck.isPinned ? "pin.slash" : "pin"
            ) {
                deck.isPinned.toggle()
                deck.updatedAt = .now
                try? modelContext.save()
                HapticService.play(.selection)
            }
            .normalActionColor()
            Button("Modifier", systemImage: "pencil") { deckToEdit = deck }
                .normalActionColor()
            Button("Dupliquer", systemImage: "plus.square.on.square") {
                LibraryActions.duplicateDeck(deck, in: modelContext)
            }
            .normalActionColor()
            Button(role: .destructive) { deckToDelete = deck } label: {
                Label("Supprimer", systemImage: "trash")
            }
            .destructiveActionColor()
        }
    }

    private var deckDeleteBinding: Binding<Bool> {
        Binding(
            get: { deckToDelete != nil },
            set: { if !$0 { deckToDelete = nil } }
        )
    }

    private func queueCreatedDeck(_ deck: Deck) {
        createdDeckToOpen = deck
        hasQueuedCreatedDeck = true
    }

    private func openCreatedDeckIfNeeded() {
        guard hasQueuedCreatedDeck, createdDeckToOpen != nil else { return }
        hasQueuedCreatedDeck = false

        Task { @MainActor in
            await Task.yield()
            showingCreatedDeck = true
        }
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
