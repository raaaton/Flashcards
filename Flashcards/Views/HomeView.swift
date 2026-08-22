import SwiftData
import SwiftUI

private struct ResumableDeck: Identifiable {
    let deck: Deck
    let snapshot: ActiveStudySessionSnapshot

    var id: UUID { deck.id }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Folder.createdAt) private var folders: [Folder]
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    @State private var showingNewFolder = false
    @State private var showingNewDeck = false
    @State private var showingFirstDeckCreation = false
    @State private var showingFirstDeckImport = false
    @State private var showingFirstDeckFolder = false
    @State private var firstDeckWantsFolder = false
    @State private var firstDeckFolder: Folder?
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var folderToEdit: Folder?
    @State private var folderToDelete: Folder?
    @State private var deckToEdit: Deck?
    @State private var deckToDelete: Deck?
    @State private var quickResumeDeck: Deck?
    @State private var quickResumeSnapshot: ActiveStudySessionSnapshot?
    @State private var showingQuickResume = false
    @State private var folderOrderIDs: [UUID] = []
    @State private var folderOrderRevision = 0
    @State private var folderReorderVisualSlots: [UUID: Int] = [:]
    @State private var folderReorderHapticsArmed = false
    @State private var folderReorderHapticPending = false
    @State private var folderReorderHapticRevision = 0

    private static let folderReorderCoordinateSpace = "folder-reorder-grid"
    private let folderGridSpacing: CGFloat = 14
    private let folderColumnCount = 2
    private let folderColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var orphanedDeckCount: Int {
        decks.count { $0.folder == nil }
    }

    private var orderedFolders: [Folder] {
        folders.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var persistedFolderOrderIDs: [UUID] {
        orderedFolders.map(\.id)
    }

    private var displayedFolders: [Folder] {
        let foldersByID = Dictionary(
            uniqueKeysWithValues: folders.map { ($0.id, $0) }
        )
        let preferredIDs = folderOrderIDs.isEmpty
            ? persistedFolderOrderIDs
            : folderOrderIDs

        var result = preferredIDs.compactMap { foldersByID[$0] }
        let knownIDs = Set(result.map(\.id))
        result.append(
            contentsOf: orderedFolders.filter { !knownIDs.contains($0.id) }
        )
        return result
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

    private var pinnedDecks: [Deck] {
        decks
            .filter(\.isPinned)
            .sorted {
                ($0.lastOpenedAt ?? $0.updatedAt) > ($1.lastOpenedAt ?? $1.updatedAt)
            }
    }

    private var resumableDecks: [ResumableDeck] {
        decks
            .compactMap { deck -> ResumableDeck? in
                guard let data = deck.activeStudySessionData,
                    let snapshot = StudySessionPersistence.decode(data, deckID: deck.id),
                    snapshot.state.currentIndex > 0,
                    snapshot.state.currentIndex < snapshot.state.items.count else {
                    return nil
                }

                let deckCardIDs = Set(deck.cards.map(\.id))
                let remainingCardIDs = snapshot.state.items
                    .dropFirst(snapshot.state.currentIndex)
                    .map(\.id)

                guard remainingCardIDs.allSatisfy(deckCardIDs.contains) else {
                    return nil
                }

                return ResumableDeck(deck: deck, snapshot: snapshot)
            }
            .sorted {
                ($0.deck.lastStudyActivityAt ?? .distantPast)
                    > ($1.deck.lastStudyActivityAt ?? .distantPast)
            }
    }

    private var showsContentBeforeFolders: Bool {
        (settings.homeResumeEnabled && !resumableDecks.isEmpty)
            || (settings.homeRecentEnabled && !recentDecks.isEmpty)
            || (settings.homePinnedEnabled && !pinnedDecks.isEmpty)
    }

    private var showsFirstDeckOnboarding: Bool {
        folders.isEmpty && decks.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if showsFirstDeckOnboarding {
                    firstDeckOnboarding
                } else {
                    folderGrid
                }
            }
            .navigationTitle("Flashcards")
            .navigationDestination(isPresented: $showingQuickResume) {
                if let quickResumeDeck, let quickResumeSnapshot {
                    StudyView(deck: quickResumeDeck, snapshot: quickResumeSnapshot)
                }
            }
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
                }
            }
        }
        .sheet(isPresented: $showingNewFolder) {
            FolderFormView()
        }
        .sheet(isPresented: $showingNewDeck) {
            DeckFormView()
        }
        .sheet(isPresented: $showingFirstDeckCreation) {
            DeckFormView()
        }
        .sheet(item: $firstDeckFolder) { folder in
            DeckFormView(initialFolder: folder)
        }
        .sheet(isPresented: $showingFirstDeckImport) {
            BackupView(autoOpenImporter: true)
        }
        .sheet(
            isPresented: $showingFirstDeckFolder,
            onDismiss: continueFirstDeckFlowAfterFolder
        ) {
            FolderFormView()
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

    private var firstDeckOnboarding: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 56)

                Image(systemName: "rectangle.stack.fill")
                    .font(
                        .system(
                            size: 54,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Crée ton premier deck")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Commence par créer un deck ou importer directement tes cartes."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    Text("Emplacement")
                        .font(.headline)

                    Picker(
                        "Emplacement",
                        selection: $firstDeckWantsFolder
                    ) {
                        Text("Sans dossier")
                            .tag(false)

                        Text("Créer un dossier")
                            .tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .background(
                    Theme.cardBackground,
                    in: .rect(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )

                VStack(spacing: 12) {
                    Button {
                        startFirstDeckCreation()
                    } label: {
                        Label(
                            "Créer mon premier deck",
                            systemImage: "plus"
                        )
                        .font(.headline)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 54
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

                    Button {
                        startFirstDeckImport()
                    } label: {
                        Label(
                            "Importer des cartes",
                            systemImage: "square.and.arrow.down"
                        )
                        .font(.headline)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 54
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 24)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private var folderGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if settings.homeResumeEnabled && !resumableDecks.isEmpty {
                    Text("Reprendre")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    LazyVStack(spacing: 10) {
                        ForEach(resumableDecks) { resumableDeck in
                            Button {
                                resume(resumableDeck)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "play.fill")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Theme.foreground(on: Theme.accent))
                                        .frame(width: 48, height: 48)
                                        .background(
                                            Theme.deckAccent(for: resumableDeck.deck).gradient,
                                            in: .circle
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(resumableDeck.deck.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)

                                        Text(
                                            "\(resumableDeck.snapshot.state.currentIndex) / \(resumableDeck.snapshot.state.items.count)"
                                        )
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(16)
                                .background(
                                    Theme.cardBackground,
                                    in: .rect(cornerRadius: 22, style: .continuous)
                                )
                                .contentShape(.rect(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reprendre \(resumableDeck.deck.name)")
                            .accessibilityValue(
                                "\(resumableDeck.snapshot.state.currentIndex) sur \(resumableDeck.snapshot.state.items.count)"
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                if settings.homeRecentEnabled && !recentDecks.isEmpty {
                    Text("Récents")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    LazyVStack(spacing: 10) {
                        ForEach(recentDecks) { deck in
                            NavigationLink {
                                DeckDetailView(deck: deck)
                            } label: {
                                DeckTile(deck: deck)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { deckContextMenu(for: deck) }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if settings.homePinnedEnabled && !pinnedDecks.isEmpty {
                    Text("Épinglés")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 10)

                    LazyVStack(spacing: 10) {
                        ForEach(pinnedDecks) { deck in
                            NavigationLink {
                                DeckDetailView(deck: deck)
                            } label: {
                                DeckTile(deck: deck)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { deckContextMenu(for: deck) }
                        }
                    }
                    .padding(.horizontal)
                }

                Text("Dossiers")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, showsContentBeforeFolders ? 10 : 0)

                if folders.isEmpty {
                    folderEmptyState
                }

                LazyVGrid(columns: folderColumns, spacing: folderGridSpacing) {
                    ForEach(displayedFolders, id: \.id) { folder in
                        NavigationLink {
                            FolderDetailView(folder: folder)
                        } label: {
                            FolderTile(
                                name: folder.name,
                                systemImage: folder.iconName,
                                deckCount: folder.decks.count
                            )
                        }
                        .buttonStyle(.plain)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(Self.folderReorderCoordinateSpace))
                        } action: { frame in
                            updateFolderReorderVisualSlot(for: folder.id, frame: frame)
                        }
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
                    .reorderable()

                    if orphanedDeckCount > 0 {
                        NavigationLink {
                            FolderDetailView(folder: nil)
                        } label: {
                            FolderTile(
                                name: L10n.text("folder.unfiled"),
                                systemImage: "tray.fill",
                                deckCount: orphanedDeckCount
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                .coordinateSpace(name: Self.folderReorderCoordinateSpace)
                .reorderContainer(for: Folder.self, itemID: \.id) { difference in
                    applyFolderReorder(difference)
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
            .padding(.bottom, 108)
        }
        .onChange(of: folders.map(\.id), initial: true) { _, _ in
            synchronizeFolderOrderFromPersistence()
            resetFolderReorderHapticState()
        }
        .animation(.spring(duration: 0.35), value: orphanedDeckCount)
        .animation(.spring(duration: 0.35), value: recentDecks.map(\.id))
        .animation(.spring(duration: 0.35), value: pinnedDecks.map(\.id))
        .concentricFloatingAction {
            addMenu
        }
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

    private func synchronizeFolderOrderFromPersistence() {
        let persistedIDs = persistedFolderOrderIDs
        guard persistedIDs != folderOrderIDs else { return }
        folderOrderIDs = persistedIDs
    }

    private func resetFolderReorderHapticState() {
        folderReorderHapticRevision += 1
        let revision = folderReorderHapticRevision

        folderReorderHapticsArmed = false
        folderReorderHapticPending = false
        folderReorderVisualSlots.removeAll(keepingCapacity: true)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard folderReorderHapticRevision == revision else { return }
            folderReorderHapticsArmed = true
        }
    }

    private func updateFolderReorderVisualSlot(for folderID: UUID, frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { return }

        let horizontalStride = frame.width + folderGridSpacing
        let verticalStride = frame.height + folderGridSpacing
        guard horizontalStride > 0, verticalStride > 0 else { return }

        let rawColumn = Int((frame.minX / horizontalStride).rounded())
        let column = min(max(rawColumn, 0), folderColumnCount - 1)
        let row = max(Int((frame.minY / verticalStride).rounded()), 0)
        let slot = (row * folderColumnCount) + column
        let previousSlot = folderReorderVisualSlots[folderID]

        folderReorderVisualSlots[folderID] = slot

        guard folderReorderHapticsArmed,
              let previousSlot,
              previousSlot != slot else {
            return
        }

        playFolderReorderHaptic()
    }

    private func playFolderReorderHaptic() {
        guard !folderReorderHapticPending else { return }

        folderReorderHapticPending = true
        HapticService.play(.reorder)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(32))
            folderReorderHapticPending = false
        }
    }

    private func applyFolderReorder<CollectionID: Hashable & Sendable>(
        _ difference: ReorderDifference<UUID, CollectionID>
    ) {
        let sourceIDs = difference.sources
        guard !sourceIDs.isEmpty else { return }

        var reorderedIDs = folderOrderIDs.isEmpty
            ? persistedFolderOrderIDs
            : folderOrderIDs
        let liveFolderIDs = Set(folders.map(\.id))
        reorderedIDs = reorderedIDs.filter { liveFolderIDs.contains($0) }

        for id in persistedFolderOrderIDs where !reorderedIDs.contains(id) {
            reorderedIDs.append(id)
        }

        let previousOrder = reorderedIDs
        let sourceSet = Set(sourceIDs)
        reorderedIDs.removeAll { sourceSet.contains($0) }

        let destinationIndex: Int
        switch difference.destination.position {
        case let .before(destinationID):
            guard let index = reorderedIDs.firstIndex(of: destinationID) else {
                return
            }
            destinationIndex = index
        case .end:
            destinationIndex = reorderedIDs.endIndex
        }

        reorderedIDs.insert(contentsOf: sourceIDs, at: destinationIndex)
        guard reorderedIDs != previousOrder else { return }

        // Keep the native reordering animation authoritative; visual slot
        // changes above provide live feedback while this callback persists the drop.
        folderOrderIDs = reorderedIDs
        folderOrderRevision += 1
        let revision = folderOrderRevision
        let finalOrder = reorderedIDs

        Task { @MainActor in
            // Keep persistence off the critical part of the native drop
            // animation so the tile becomes interactive again immediately.
            try? await Task.sleep(for: .milliseconds(250))
            guard folderOrderRevision == revision else { return }
            persistFolderOrder(finalOrder)
        }
    }

    private func persistFolderOrder(_ orderedIDs: [UUID]) {
        let sortOrderByID = Dictionary(
            uniqueKeysWithValues: orderedIDs.enumerated().map {
                ($0.element, $0.offset)
            }
        )

        for folder in folders {
            guard let sortOrder = sortOrderByID[folder.id] else { continue }
            folder.sortOrder = sortOrder
        }

        try? modelContext.save()
    }

    private func startFirstDeckCreation() {
        firstDeckFolder = nil

        if firstDeckWantsFolder {
            showingFirstDeckFolder = true
        } else {
            showingFirstDeckCreation = true
        }
    }

    private func startFirstDeckImport() {
        firstDeckFolder = nil
        showingFirstDeckImport = true
    }

    private func continueFirstDeckFlowAfterFolder() {
        guard firstDeckWantsFolder else { return }

        Task { @MainActor in
            // Attend seulement que SwiftData/@Query voie
            // le Folder qui vient d'être sauvegardé.
            for _ in 0..<20 {
                if let createdFolder = folders.first {
                    // Le Folder lui-même déclenche maintenant
                    // la présentation du DeckForm.
                    firstDeckFolder = createdFolder
                    return
                }

                try? await Task.sleep(
                    for: .milliseconds(50)
                )
            }

            // Aucun Folder apparu :
            // le formulaire a probablement été annulé.
        }
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
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .glassEffect(
                    .regular.interactive(),
                    in: .circle
                )
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    private func deckContextMenu(for deck: Deck) -> some View {
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

        Button("Modifier", systemImage: "pencil") {
            deckToEdit = deck
        }
        .normalActionColor()

        Button("Dupliquer", systemImage: "plus.square.on.square") {
            LibraryActions.duplicateDeck(deck, in: modelContext)
        }
        .normalActionColor()

        Button(role: .destructive) {
            deckToDelete = deck
        } label: {
            Label("Supprimer", systemImage: "trash")
        }
        .destructiveActionColor()
    }

    private func resume(_ resumable: ResumableDeck) {
        resumable.deck.lastStudyActivityAt = .now
        try? modelContext.save()
        quickResumeDeck = resumable.deck
        quickResumeSnapshot = resumable.snapshot
        showingQuickResume = true
    }
}
