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
    @State private var showingSettings = false
    @State private var folderToEdit: Folder?
    @State private var folderToDelete: Folder?
    @State private var deckToEdit: Deck?
    @State private var deckToDelete: Deck?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var matchingDecks: [Deck] {
        guard !searchText.isEmpty else { return [] }
        return decks.filter { deck in
            deck.name.localizedCaseInsensitiveContains(searchText)
                || (deck.deckDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
                || deck.cards.contains { card in
                    card.term.localizedCaseInsensitiveContains(searchText)
                        || card.definition.localizedCaseInsensitiveContains(searchText)
                }
        }
    }

    private var orphanedDeckCount: Int {
        decks.count { $0.folder == nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    folderGrid
                } else if matchingDecks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    searchResults
                }
            }
            .navigationTitle("Flashcards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.title", systemImage: "gearshape") {
                        showingSettings = true
                    }
                    .foregroundStyle(.white)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomControls
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $folderToEdit) { folder in
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

    private var folderGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(folders) { folder in
                    NavigationLink {
                        FolderDetailView(folder: folder)
                    } label: {
                        FolderTile(
                            name: folder.name,
                            systemImage: folder.iconName,
                            color: Color(folderHex: folder.colorHex),
                            deckCount: folder.decks.count
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Modifier", systemImage: "pencil") { folderToEdit = folder }
                            .foregroundStyle(.white)
                        Button("Dupliquer", systemImage: "plus.square.on.square") {
                            LibraryActions.duplicateFolder(folder, in: modelContext)
                        }
                        .foregroundStyle(.white)
                        Button(role: .destructive) { folderToDelete = folder } label: {
                            Label("Supprimer", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }

                if orphanedDeckCount > 0 {
                    NavigationLink {
                        FolderDetailView(folder: nil)
                    } label: {
                        FolderTile(
                            name: L10n.text("folder.unfiled"),
                            systemImage: "tray.fill",
                            color: .gray,
                            deckCount: orphanedDeckCount
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .animation(.spring(duration: 0.35), value: folders.map(\.id))
        .animation(.spring(duration: 0.35), value: orphanedDeckCount)
    }

    private var searchResults: some View {
        List {
            Section("Résultats") {
                ForEach(matchingDecks) { deck in
                    NavigationLink {
                        DeckDetailView(deck: deck)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            DeckRow(deck: deck)
                            Label(deck.folder?.name ?? L10n.text("folder.unfiled"), systemImage: "folder")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deckToDelete = deck } label: {
                            Label("Supprimer", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                        .tint(Theme.cardBackground)
                        Button { LibraryActions.duplicateDeck(deck, in: modelContext) } label: {
                            Label("Dupliquer", systemImage: "plus.square.on.square")
                                .foregroundStyle(.white)
                        }
                        .tint(Theme.accent)
                    }
                    .contextMenu {
                        Button("Modifier", systemImage: "pencil") { deckToEdit = deck }
                            .foregroundStyle(.white)
                        Button("Dupliquer", systemImage: "plus.square.on.square") {
                            LibraryActions.duplicateDeck(deck, in: modelContext)
                        }
                        .foregroundStyle(.white)
                        Button(role: .destructive) { deckToDelete = deck } label: {
                            Label("Supprimer", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .animation(.default, value: matchingDecks.map(\.id))
    }

    private var bottomControls: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white)

                    TextField("Decks et cartes", text: $searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Effacer la recherche")
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18, style: .continuous))

                addMenu
                    .frame(width: 52, height: 52)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var addMenu: some View {
        Menu {
            Button("Nouveau deck", systemImage: "rectangle.stack.badge.plus") {
                showingNewDeck = true
            }
            .foregroundStyle(.white)
            Button("Nouveau dossier", systemImage: "folder.badge.plus") {
                showingNewFolder = true
            }
            .foregroundStyle(.white)
            Divider()
            Button("Importer en masse", systemImage: "text.badge.plus") {
                showingBulkImport = true
            }
            .foregroundStyle(.white)
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Ajouter")
        .accessibilityHint("Créer un deck ou un dossier")
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

    private func deleteFolderKeepingDecks() {
        guard let folder = folderToDelete else { return }
        LibraryActions.deleteFolderKeepingDecks(folder, in: modelContext)
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
