import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var showingEditDeck = false
    @State private var showingExport = false
    @State private var confirmingDeletion = false
    @State private var didRecordOpening = false

    private var orderedCards: [Card] {
        deck.cards.sorted { $0.position < $1.position }
    }

    private var masteredCount: Int {
        deck.cards.count(where: \.mastered)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                deckSummary
                studySection
                cardsSection
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: recordOpening)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Modifier le deck", systemImage: "pencil") { showingEditDeck = true }
                        .normalActionColor()
                    Button("Exporter en JSON", systemImage: "square.and.arrow.up") {
                        showingExport = true
                    }
                    .normalActionColor()
                    Button(role: .destructive) {
                        confirmingDeletion = true
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                    .destructiveActionColor()
                } label: {
                    Image(systemName: "ellipsis")
                        .neutralIconColor()
                }
                .accessibilityLabel("Actions")
            }
        }
        .sheet(isPresented: $showingEditDeck) {
            DeckFormView(deck: deck)
        }
        .sheet(isPresented: $showingExport) {
            BackupView(deck: deck)
        }
        .alert("Supprimer ce deck ?", isPresented: $confirmingDeletion) {
            Button("Supprimer", role: .destructive) {
                modelContext.delete(deck)
                try? modelContext.save()
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes ses cartes seront supprimées définitivement.")
        }
    }

    private var deckSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let description = deck.deckDescription, !description.isEmpty {
                Text(description)
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: deck.cards.isEmpty ? 0 : Double(masteredCount) / Double(deck.cards.count)
            ) {
                Text("Progression")
            } currentValueLabel: {
                Text("\(masteredCount) / \(deck.cards.count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var studySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Réviser")
                .font(.title2.bold())

            HStack(spacing: 12) {
                studyTile(
                    title: "Flashcards",
                    systemImage: "rectangle.on.rectangle.angled"
                ) {
                    StudySetupView(deck: deck)
                }

                studyTile(title: "Test", systemImage: "checklist") {
                    TestSetupView(deck: deck)
                }
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cartes")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    EditCardsView(deck: deck)
                } label: {
                    Label("Modifier les cartes", systemImage: "square.and.pencil")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 15)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .normalActionColor()

                Divider()

                if orderedCards.isEmpty {
                    Text("Ce deck ne contient encore aucune carte.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 18)
                } else {
                    ForEach(orderedCards.prefix(5)) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.term)
                                .font(.headline)
                            Text(card.definition)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 13)

                        if card.id != orderedCards.prefix(5).last?.id {
                            Divider()
                        }
                    }

                    if orderedCards.count > 5 {
                        Divider()
                        Text(L10n.format("deck.more_cards", Int64(orderedCards.count - 5)))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 13)
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(Theme.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
        }
    }

    private func studyTile<Destination: View>(
        title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Theme.accent, in: .rect(cornerRadius: 18, style: .continuous))
            .contentShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(deck.cards.isEmpty)
        .opacity(deck.cards.isEmpty ? 0.45 : 1)
    }

    private func recordOpening() {
        guard !didRecordOpening else { return }
        didRecordOpening = true
        deck.lastOpenedAt = .now
        try? modelContext.save()
    }
}
