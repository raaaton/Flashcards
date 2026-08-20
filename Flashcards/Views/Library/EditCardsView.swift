import SwiftData
import SwiftUI

private enum CardTransferMode: String {
    case move
    case copy

    var title: String {
        switch self {
        case .move: "Déplacer les cartes"
        case .copy: "Copier les cartes"
        }
    }
}

private struct CardTransferRequest: Identifiable {
    let id = UUID()
    let mode: CardTransferMode
    let cardIDs: Set<UUID>
}

struct EditCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    let deck: Deck

    @State private var showingNewCard = false
    @State private var showingBulkImport = false
    @State private var cardToEdit: Card?
    @State private var isSelecting = false
    @State private var selectedCardIDs: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var transferRequest: CardTransferRequest?

    private var orderedCards: [Card] {
        deck.cards.sorted { $0.position < $1.position }
    }

    private var selectedCards: [Card] {
        orderedCards.filter { selectedCardIDs.contains($0.id) }
    }

    private var shouldStarSelection: Bool {
        selectedCards.contains { !$0.isStarred }
    }

    var body: some View {
        List {
            ForEach(orderedCards) { card in
                cardRow(card)
                    .contentShape(.rect)
                    .contextMenu {
                        Button(
                            card.isStarred ? "Retirer des favoris" : "Ajouter aux favoris",
                            systemImage: card.isStarred ? "star.slash" : "star"
                        ) {
                            setStarred(!card.isStarred, cards: [card])
                        }
                        Button("Déplacer vers un deck", systemImage: "folder") {
                            beginTransfer(.move, cardIDs: [card.id])
                        }
                        Button("Copier vers un deck", systemImage: "doc.on.doc") {
                            beginTransfer(.copy, cardIDs: [card.id])
                        }
                        Divider()
                        Button("Supprimer", systemImage: "trash", role: .destructive) {
                            selectedCardIDs = [card.id]
                            showingDeleteConfirmation = true
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: !isSelecting) {
                        if !isSelecting {
                            Button(role: .destructive) {
                                LibraryActions.deleteCards([card], from: deck, in: modelContext)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
            }
            .onMove(perform: reorderCards)
        }
        .overlay {
            if orderedCards.isEmpty {
                ContentUnavailableView(
                    "Aucune carte",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Ajoutez une carte avec le bouton +.")
                )
            }
        }
        .navigationTitle(isSelecting ? "\(selectedCardIDs.count) sélectionnée(s)" : "Modifier les cartes")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingNewCard) {
            CardFormView(deck: deck)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(deck: deck)
        }
        .sheet(item: $cardToEdit) { card in
            CardFormView(deck: deck, card: card)
        }
        .sheet(item: $transferRequest) { request in
            CardTransferSheet(
                sourceDeck: deck,
                cards: orderedCards.filter { request.cardIDs.contains($0.id) },
                mode: request.mode
            ) {
                endSelection()
            }
        }
        .alert("Supprimer les cartes ?", isPresented: $showingDeleteConfirmation) {
            Button("Annuler", role: .cancel) {
                if !isSelecting { selectedCardIDs.removeAll() }
            }
            Button("Supprimer", role: .destructive) {
                LibraryActions.deleteCards(selectedCards, from: deck, in: modelContext)
                endSelection()
            }
        } message: {
            Text("Cette action supprimera définitivement \(selectedCardIDs.count) carte(s).")
        }
    }

    @ViewBuilder
    private func cardRow(_ card: Card) -> some View {
        HStack(spacing: 12) {
            if isSelecting {
                Button {
                    toggleSelection(card.id)
                } label: {
                    Image(
                        systemName: selectedCardIDs.contains(card.id)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .font(.title3)
                    .foregroundStyle(
                        selectedCardIDs.contains(card.id) ? Theme.accent : Color.secondary
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    selectedCardIDs.contains(card.id) ? "Désélectionner" : "Sélectionner"
                )
            }

            Button {
                if isSelecting {
                    toggleSelection(card.id)
                } else {
                    cardToEdit = card
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.term)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(card.definition)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isSelecting ? "Basculer la sélection" : "Modifier cette carte")

            Button {
                setStarred(!card.isStarred, cards: [card])
            } label: {
                Image(systemName: card.isStarred ? "star.fill" : "star")
                    .foregroundStyle(card.isStarred ? .yellow : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                card.isStarred ? L10n.text("card.unstar") : L10n.text("card.star")
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { endSelection() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(selectedCardIDs.count == orderedCards.count ? "Aucune" : "Toutes") {
                    if selectedCardIDs.count == orderedCards.count {
                        selectedCardIDs.removeAll()
                    } else {
                        selectedCardIDs = Set(orderedCards.map(\.id))
                    }
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
                .disabled(selectedCardIDs.isEmpty)

                Spacer()

                Button {
                    beginTransfer(.move, cardIDs: selectedCardIDs)
                } label: {
                    Label("Déplacer", systemImage: "folder")
                }
                .disabled(selectedCardIDs.isEmpty)

                Spacer()

                Button {
                    beginTransfer(.copy, cardIDs: selectedCardIDs)
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                }
                .disabled(selectedCardIDs.isEmpty)

                Spacer()

                Button {
                    setStarred(shouldStarSelection, cards: selectedCards)
                } label: {
                    Label(
                        shouldStarSelection ? "Favoris" : "Retirer",
                        systemImage: shouldStarSelection ? "star" : "star.slash"
                    )
                }
                .disabled(selectedCardIDs.isEmpty)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .tint(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Ajouter une carte", systemImage: "plus") { showingNewCard = true }
                        .normalActionColor()
                    Button("Importer en masse", systemImage: "text.badge.plus") { showingBulkImport = true }
                        .normalActionColor()
                    Divider()
                    Button("Sélectionner", systemImage: "checkmark.circle") {
                        beginSelection()
                    }
                    .disabled(orderedCards.isEmpty)
                } label: {
                    Image(systemName: "plus")
                        .neutralIconColor()
                }
                .tint(.white)
                .accessibilityLabel("Ajouter ou sélectionner")
            }
        }
    }

    private func beginSelection() {
        editMode?.wrappedValue = .inactive
        selectedCardIDs.removeAll()
        isSelecting = true
    }

    private func endSelection() {
        selectedCardIDs.removeAll()
        isSelecting = false
    }

    private func toggleSelection(_ id: UUID) {
        if selectedCardIDs.contains(id) {
            selectedCardIDs.remove(id)
        } else {
            selectedCardIDs.insert(id)
        }
        HapticService.play(.selection)
    }

    private func setStarred(_ isStarred: Bool, cards: [Card]) {
        LibraryActions.setStarred(
            isStarred,
            for: cards,
            in: deck,
            modelContext: modelContext
        )
        HapticService.play(.selection)
    }

    private func beginTransfer(_ mode: CardTransferMode, cardIDs: Set<UUID>) {
        guard !cardIDs.isEmpty else { return }
        transferRequest = CardTransferRequest(mode: mode, cardIDs: cardIDs)
    }

    private func reorderCards(from source: IndexSet, to destination: Int) {
        var cards = orderedCards
        cards.move(fromOffsets: source, toOffset: destination)
        for (position, card) in cards.enumerated() {
            card.position = position
        }
        deck.updatedAt = .now
        try? modelContext.save()
    }
}

private struct CardTransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.name) private var decks: [Deck]

    let sourceDeck: Deck
    let cards: [Card]
    let mode: CardTransferMode
    let onComplete: () -> Void

    @State private var destinationDeckID: UUID?

    private var destinationDecks: [Deck] {
        decks.filter { $0.id != sourceDeck.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    if destinationDecks.isEmpty {
                        ContentUnavailableView(
                            "Aucun autre deck",
                            systemImage: "rectangle.stack",
                            description: Text("Créez un autre deck avant de déplacer ou copier des cartes.")
                        )
                    } else {
                        Picker("Deck", selection: $destinationDeckID) {
                            ForEach(destinationDecks) { deck in
                                Text(deck.name).tag(deck.id as UUID?)
                            }
                        }
                    }
                }

                Section {
                    Label("\(cards.count) carte(s)", systemImage: "rectangle.stack")
                    if mode == .copy {
                        Text("Les favoris sont conservés. La progression des copies repart à zéro.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("La progression, les statistiques et les favoris sont conservés.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(destinationDeckID == nil || cards.isEmpty)
                }
            }
            .onAppear {
                if destinationDeckID == nil {
                    destinationDeckID = destinationDecks.first?.id
                }
            }
        }
    }

    private func save() {
        guard let destination = destinationDecks.first(where: { $0.id == destinationDeckID }) else {
            return
        }
        switch mode {
        case .move:
            LibraryActions.moveCards(
                cards,
                from: sourceDeck,
                to: destination,
                in: modelContext
            )
        case .copy:
            LibraryActions.copyCards(cards, to: destination, in: modelContext)
        }
        HapticService.play(.selection)
        onComplete()
        dismiss()
    }
}
