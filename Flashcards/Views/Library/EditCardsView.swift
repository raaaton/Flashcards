import SwiftData
import SwiftUI

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
