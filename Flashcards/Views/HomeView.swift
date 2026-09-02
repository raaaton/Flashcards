import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private struct ResumableDeck: Identifiable {
    let deck: Deck
    let session: ResumableSession

    var id: String { "\(deck.id.uuidString)-\(session.id)" }
}

private enum ResumableSession {
    case flashcards(ActiveStudySessionSnapshot)
    case test(ActiveTestSessionSnapshot)

    var id: String {
        switch self {
        case .flashcards: "flashcards"
        case .test: "test"
        }
    }

    var title: String {
        switch self {
        case .flashcards: L10n.text("Flashcards")
        case .test: L10n.text("Test")
        }
    }

    var currentCount: Int {
        switch self {
        case let .flashcards(snapshot): snapshot.state.currentIndex
        case let .test(snapshot): snapshot.state.answers.count
        }
    }

    var totalCount: Int {
        switch self {
        case let .flashcards(snapshot): snapshot.state.items.count
        case let .test(snapshot): snapshot.state.questions.count
        }
    }
}

private struct FolderReorderDropDelegate: DropDelegate {
    let destinationID: UUID
    @Binding var draggedID: UUID?
    let move: (UUID, UUID) -> Void
    let finish: () -> Void

    func dropEntered(info: DropInfo) {
        guard let sourceID = draggedID,
              sourceID != destinationID else {
            return
        }

        move(sourceID, destinationID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        finish()
        return true
    }
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
    @State private var createdDeckToOpen: Deck?
    @State private var hasQueuedCreatedDeck = false
    @State private var showingCreatedDeck = false
    @State private var quickResume: ResumableDeck?
    @State private var showingQuickResume = false
    @State private var folderOrderIDs: [UUID] = []
    @State private var folderOrderRevision = 0
    @State private var draggedFolderID: UUID?
    @State private var folderDragPreviewSize: CGSize = .zero
    @State private var folderReorderVisualSlots: [UUID: Int] = [:]
    @State private var folderReorderHapticsArmed = false
    @State private var folderReorderHapticPending = false
    @State private var folderReorderHapticRevision = 0
    @State private var folderReorderIsActive = false

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
            .flatMap { deck -> [ResumableDeck] in
                let deckCardIDs = Set(deck.cards.map(\.id))
                var sessions: [ResumableDeck] = []

                if let data = deck.activeStudySessionData,
                   let snapshot = StudySessionPersistence.decode(data, deckID: deck.id),
                   snapshot.state.currentIndex > 0,
                   snapshot.state.currentIndex < snapshot.state.items.count {
                    let remainingCardIDs = snapshot.state.items
                        .dropFirst(snapshot.state.currentIndex)
                        .map(\.id)
                    if remainingCardIDs.allSatisfy(deckCardIDs.contains) {
                        sessions.append(
                            ResumableDeck(deck: deck, session: .flashcards(snapshot))
                        )
                    }
                }

                if let data = deck.activeTestSessionData,
                   let snapshot = TestSessionPersistence.decode(data, deckID: deck.id),
                   snapshot.state.questions.allSatisfy({ deckCardIDs.contains($0.cardID) }) {
                    sessions.append(
                        ResumableDeck(deck: deck, session: .test(snapshot))
                    )
                }

                return sessions
            }
            .sorted {
                activityDate(for: $0) > activityDate(for: $1)
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
            .navigationTitle("Kavi")
            .navigationDestination(isPresented: $showingQuickResume) {
                if let quickResume {
                    switch quickResume.session {
                    case let .flashcards(snapshot):
                        StudyView(deck: quickResume.deck, snapshot: snapshot)
                    case let .test(snapshot):
                        TestRunView(deck: quickResume.deck, snapshot: snapshot)
                    }
                }
            }
            .navigationDestination(isPresented: $showingCreatedDeck) {
                if let createdDeckToOpen {
                    DeckDetailView(deck: createdDeckToOpen)
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
        .sheet(
            isPresented: $showingNewDeck,
            onDismiss: openCreatedDeckIfNeeded
        ) {
            DeckFormView(onCreated: queueCreatedDeck)
        }
        .sheet(
            isPresented: $showingFirstDeckCreation,
            onDismiss: openCreatedDeckIfNeeded
        ) {
            DeckFormView(onCreated: queueCreatedDeck)
        }
        .sheet(
            item: $firstDeckFolder,
            onDismiss: openCreatedDeckIfNeeded
        ) { folder in
            DeckFormView(
                initialFolder: folder,
                onCreated: queueCreatedDeck
            )
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
        .background {
            Color.clear
                .alert("Supprimer ce deck ?", isPresented: deckDeleteBinding) {
                    Button("Supprimer", role: .destructive) { deletePendingDeck() }
                    Button("Annuler", role: .cancel) { deckToDelete = nil }
                        .normalActionColor()
                } message: {
                    Text("Toutes ses cartes seront supprimées définitivement.")
                }
                .tint(.white)
        }
        .background {
            Color.clear
                .alert("Supprimer ce dossier ?", isPresented: folderDeleteBinding) {
                    Button("Tout supprimer", role: .destructive) { deleteFolderWithDecks() }
                    Button("Conserver les decks") { deleteFolderKeepingDecks() }
                        .normalActionColor()
                    Button("Annuler", role: .cancel) { folderToDelete = nil }
                        .normalActionColor()
                } message: {
                    Text("Vous pouvez déplacer les decks vers « Sans dossier » ou supprimer définitivement tout le contenu.")
                }
                .tint(.white)
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

                                        HStack(spacing: 6) {
                                            Text(resumableDeck.session.title)
                                            Text("•")
                                                .accessibilityHidden(true)
                                            Text(
                                                "\(resumableDeck.session.currentCount) / \(resumableDeck.session.totalCount)"
                                            )
                                            .monospacedDigit()
                                        }
                                        .font(.subheadline)
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    resetProgress(for: resumableDeck)
                                } label: {
                                    Label(
                                        L10n.text("Réinitialiser la progression"),
                                        systemImage: "arrow.counterclockwise"
                                    )
                                }
                                .tint(.red)
                            }
                            .accessibilityLabel(
                                "Reprendre \(resumableDeck.session.title), \(resumableDeck.deck.name)"
                            )
                            .accessibilityValue(
                                "\(resumableDeck.session.currentCount) sur \(resumableDeck.session.totalCount)"
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

                if #available(iOS 27.0, *) {
                    nativeFolderGrid
                } else {
                    classicFolderGrid
                }
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

    @available(iOS 27.0, *)
    private var nativeFolderGrid: some View {
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
                .contextMenu { folderContextMenu(for: folder) }
            }
            .reorderable()

            unfiledFolderTile
        }
        .coordinateSpace(name: Self.folderReorderCoordinateSpace)
        .reorderContainer(for: Folder.self, itemID: \.id) { difference in
            applyFolderReorder(difference)
        }
        .onDragSessionUpdated { session in
            updateFolderReorderDragSession(session)
        }
        .padding(.horizontal)
    }

    private var classicFolderGrid: some View {
        LazyVGrid(columns: folderColumns, spacing: folderGridSpacing) {
            ForEach(displayedFolders, id: \.id) { folder in
                ZStack {
                    FolderTile(
                        name: folder.name,
                        systemImage: folder.iconName,
                        deckCount: folder.decks.count
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

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
                        folderDragPreviewSize = frame.size
                        updateFolderReorderVisualSlot(for: folder.id, frame: frame)
                    }
                    .onDrag {
                        draggedFolderID = folder.id
                        folderReorderIsActive = true
                        return NSItemProvider(object: folder.id.uuidString as NSString)
                    } preview: {
                        FolderTile(
                            name: folder.name,
                            systemImage: folder.iconName,
                            deckCount: folder.decks.count
                        )
                        .frame(
                            width: folderDragPreviewSize.width > 0
                                ? folderDragPreviewSize.width
                                : 170
                        )
                        .contentShape(
                            .dragPreview,
                            .rect(cornerRadius: 22, style: .continuous)
                        )
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: FolderReorderDropDelegate(
                            destinationID: folder.id,
                            draggedID: $draggedFolderID,
                            move: moveFolderDuringCustomDrag,
                            finish: finishFolderCustomDrag
                        )
                    )
                    .contextMenu { folderContextMenu(for: folder) }
                }
            }

            unfiledFolderTile
        }
        .coordinateSpace(name: Self.folderReorderCoordinateSpace)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var unfiledFolderTile: some View {
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

    @ViewBuilder
    private func folderContextMenu(for folder: Folder) -> some View {
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

    private func moveFolderDuringCustomDrag(_ sourceID: UUID, _ destinationID: UUID) {
        guard sourceID != destinationID else { return }

        var reorderedIDs = folderOrderIDs.isEmpty
            ? persistedFolderOrderIDs
            : folderOrderIDs
        let liveFolderIDs = Set(folders.map(\.id))
        reorderedIDs = reorderedIDs.filter { liveFolderIDs.contains($0) }

        for id in persistedFolderOrderIDs where !reorderedIDs.contains(id) {
            reorderedIDs.append(id)
        }

        guard let sourceIndex = reorderedIDs.firstIndex(of: sourceID),
              let destinationIndex = reorderedIDs.firstIndex(of: destinationID) else {
            return
        }

        let destinationOffset = destinationIndex > sourceIndex
            ? destinationIndex + 1
            : destinationIndex

        withAnimation(.spring(duration: 0.24)) {
            reorderedIDs.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destinationOffset
            )
            folderOrderIDs = reorderedIDs
        }
    }

    private func finishFolderCustomDrag() {
        guard draggedFolderID != nil else { return }

        draggedFolderID = nil
        folderReorderIsActive = false
        folderReorderHapticPending = false
        let finalOrder = folderOrderIDs.isEmpty
            ? persistedFolderOrderIDs
            : folderOrderIDs
        persistFolderOrder(finalOrder)
    }

    private func resetFolderReorderHapticState() {
        folderReorderHapticRevision += 1
        let revision = folderReorderHapticRevision

        draggedFolderID = nil
        folderReorderIsActive = false
        folderReorderHapticsArmed = false
        folderReorderHapticPending = false
        folderReorderVisualSlots.removeAll(keepingCapacity: true)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard folderReorderHapticRevision == revision else { return }
            folderReorderHapticsArmed = true
        }
    }

    @available(iOS 27.0, *)
    private func updateFolderReorderDragSession(_ session: DragSession) {
        switch session.phase {
        case .initial, .active:
            folderReorderIsActive = true
        case .ending(_), .ended(_), .dataTransferCompleted:
            folderReorderIsActive = false
            folderReorderHapticPending = false
        @unknown default:
            folderReorderIsActive = false
            folderReorderHapticPending = false
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

        guard folderReorderIsActive,
              folderReorderHapticsArmed,
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

    @available(iOS 27.0, *)
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
        switch resumable.session {
        case .flashcards:
            resumable.deck.lastStudyActivityAt = .now
        case .test:
            resumable.deck.lastTestActivityAt = .now
        }
        try? modelContext.save()
        quickResume = resumable
        showingQuickResume = true
    }

    private func resetProgress(for resumable: ResumableDeck) {
        switch resumable.session {
        case .flashcards:
            LibraryActions.resetStudyProgress(for: resumable.deck, in: modelContext)
        case .test:
            LibraryActions.resetTestProgress(for: resumable.deck, in: modelContext)
        }
        HapticService.play(.selection)
    }

    private func activityDate(for resumable: ResumableDeck) -> Date {
        return switch resumable.session {
        case .flashcards:
            resumable.deck.lastStudyActivityAt ?? .distantPast
        case .test:
            resumable.deck.lastTestActivityAt ?? .distantPast
        }
    }
}
