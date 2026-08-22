import SwiftData
import SwiftUI

struct DeckRow: View {
    let deck: Deck

    private var masteredCount: Int {
        deck.cards.count(where: \.mastered)
    }

    private var progress: Double {
        guard !deck.cards.isEmpty else { return 0 }
        return Double(masteredCount) / Double(deck.cards.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(deck.name)
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                Text(L10n.cards(deck.cards.count))
                Spacer()
                Text("\(Int(progress * 100)) %")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ProgressView(value: progress)
                .accessibilityLabel(L10n.format("deck.progress.label", deck.name))
                .accessibilityValue(
                    L10n.format(
                        "deck.progress.value",
                        Int64(masteredCount),
                        Int64(deck.cards.count)
                    )
                )
        }
        .padding(.vertical, 4)
    }
}

struct DeckTile: View {
    let deck: Deck

    private var folderIcon: String {
        deck.folder?.iconName ?? "tray.fill"
    }

    private var folderColor: Color {
        Theme.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: folderIcon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.foreground(on: folderColor))
                .frame(width: 44, height: 44)
                .background(folderColor.gradient, in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(deck.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(L10n.cards(deck.cards.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(Theme.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .contentShape(.rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvrir ce deck")
    }
}

private struct CardSearchMatch: Identifiable {
    let card: Card
    let deck: Deck

    var id: UUID { card.id }
}

struct DeckSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Query(sort: \Deck.name) private var allDecks: [Deck]

    let decks: [Deck]
    let showsFolderContext: Bool

    @State private var query = ""
    @State private var searchIsPresented = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14)
    ]

    private var cleanQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var usesGlobalScope: Bool {
        showsFolderContext || !settings.searchScopeEnabled
    }

    private var searchableDecks: [Deck] {
        usesGlobalScope ? allDecks : decks
    }

    private var matchingFolders: [Folder] {
        guard usesGlobalScope, !cleanQuery.isEmpty else { return [] }
        return folders.filter { $0.name.localizedCaseInsensitiveContains(cleanQuery) }
    }

    private var matchingDecks: [Deck] {
        guard !cleanQuery.isEmpty else { return [] }
        return searchableDecks.filter { deck in
            deck.name.localizedCaseInsensitiveContains(cleanQuery)
        }
    }

    private var matchingCards: [CardSearchMatch] {
        guard usesGlobalScope, !cleanQuery.isEmpty else { return [] }
        return searchableDecks.flatMap { deck in
            deck.cards
                .filter {
                    $0.term.localizedCaseInsensitiveContains(cleanQuery)
                        || $0.definition.localizedCaseInsensitiveContains(cleanQuery)
                }
                .sorted { $0.position < $1.position }
                .map { CardSearchMatch(card: $0, deck: deck) }
        }
    }

    private var hasResults: Bool {
        !matchingFolders.isEmpty || !matchingDecks.isEmpty || !matchingCards.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if cleanQuery.isEmpty {
                    ContentUnavailableView(
                        "Rechercher",
                        systemImage: "magnifyingglass",
                        description: Text("Recherchez un dossier, un deck ou le contenu d’une carte.")
                    )
                } else if !hasResults {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            if !matchingFolders.isEmpty {
                                resultHeader("Dossiers", systemImage: "folder")
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(matchingFolders) { folder in
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
                                    }
                                }
                            }

                            if !matchingDecks.isEmpty {
                                resultHeader("Decks", systemImage: "rectangle.stack")
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(matchingDecks) { deck in
                                        NavigationLink {
                                            DeckDetailView(deck: deck)
                                        } label: {
                                            DeckTile(deck: deck)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if !matchingCards.isEmpty {
                                resultHeader("Cartes", systemImage: "rectangle.on.rectangle")
                                LazyVStack(spacing: 10) {
                                    ForEach(matchingCards) { match in
                                        NavigationLink {
                                            DeckDetailView(deck: match.deck)
                                        } label: {
                                            cardPreview(match)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                    .animation(.default, value: matchingDecks.map(\.id))
                    .animation(.default, value: matchingCards.map(\.id))
                }
            }
            .navigationTitle("Rechercher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .neutralIconColor()
                    }
                    .tint(.white)
                    .accessibilityLabel("Fermer")
                }
            }
        }
        .searchable(
            text: $query,
            isPresented: $searchIsPresented,
            prompt: usesGlobalScope ? "Dossiers, decks et cartes" : "Decks"
        )
        .scrollDismissesKeyboard(.interactively)
        .task {
            searchIsPresented = true
        }
    }

    private func resultHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title2.bold())
            .foregroundStyle(.primary)
    }

    private func cardPreview(_ match: CardSearchMatch) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(match.card.term)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(match.card.definition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Label(
                "\(match.deck.folder?.name ?? L10n.text("folder.unfiled")) › \(match.deck.name)",
                systemImage: match.deck.folder?.iconName ?? "tray.fill"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.deckAccent(for: match.deck))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Theme.cardBackground, in: .rect(cornerRadius: 18, style: .continuous))
        .contentShape(.rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvrir le deck \(match.deck.name)")
    }
}
