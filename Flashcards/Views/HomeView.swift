import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.createdAt) private var folders: [Folder]
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    @State private var showingNewFolder = false
    @State private var showingNewDeck = false
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var folderToEdit: Folder?
    @State private var folderToDelete: Folder?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var orphanedDeckCount: Int {
        decks.count { $0.folder == nil }
    }

    private var recentDecks: [Deck] {
        Array(
            decks
                .filter { $0.lastOpenedAt != nil }
                .sorted {
                    ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast)
                }
                .prefix(2)
        )
    }

    var body: some View {
        NavigationStack {
            folderGrid
            .navigationTitle("Flashcards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .neutralIconColor()
                    }
                    .tint(.white)
                    .accessibilityLabel("settings.title")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .neutralIconColor()
                    }
                    .tint(.white)
                    .accessibilityLabel("Rechercher")

                    addMenu
                }
            }
        }
        .sheet(isPresented: $showingNewFolder) {
            FolderFormView()
        }
        .sheet(isPresented: $showingNewDeck) {
            DeckFormView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingSearch) {
            DeckSearchView(decks: decks, showsFolderContext: true)
        }
        .sheet(item: $folderToEdit) { folder in
            FolderFormView(folder: folder)
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
    }

    private var folderGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !recentDecks.isEmpty {
                    Text("Récents")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(recentDecks) { deck in
                            NavigationLink {
                                DeckDetailView(deck: deck)
                            } label: {
                                DeckTile(deck: deck)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Text("Dossiers")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, recentDecks.isEmpty ? 0 : 10)

                if folders.isEmpty {
                    folderEmptyState
                }

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
                                .normalActionColor()
                            Button("Dupliquer", systemImage: "plus.square.on.square") {
                                LibraryActions.duplicateFolder(folder, in: modelContext)
                            }
                            .normalActionColor()
                            Button(role: .destructive) { folderToDelete = folder } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                            .destructiveActionColor()
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

            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .animation(.spring(duration: 0.35), value: folders.map(\.id))
        .animation(.spring(duration: 0.35), value: orphanedDeckCount)
        .animation(.spring(duration: 0.35), value: recentDecks.map(\.id))
    }

    private var folderEmptyState: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Aucun dossier pour le moment")
                .font(.headline)
            Text("Créez un dossier pour organiser vos decks.")
                .foregroundStyle(.secondary)
            Button("Créer un dossier", systemImage: "folder.badge.plus") {
                showingNewFolder = true
            }
            .normalActionColor()
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.cardBackground, in: .rect(cornerRadius: 18, style: .continuous))
        .padding(.horizontal)
    }

    private var addMenu: some View {
        Menu {
            Button("Nouveau deck", systemImage: "rectangle.stack.badge.plus") {
                showingNewDeck = true
            }
            .normalActionColor()
            Button("Nouveau dossier", systemImage: "folder.badge.plus") {
                showingNewFolder = true
            }
            .normalActionColor()
        } label: {
            Image(systemName: "plus")
                .neutralIconColor()
        }
        .tint(.white)
        .accessibilityLabel("Ajouter")
        .accessibilityHint("Créer un deck ou un dossier")
    }

    private var folderDeleteBinding: Binding<Bool> {
        Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
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

}
