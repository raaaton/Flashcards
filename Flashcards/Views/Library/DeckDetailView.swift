import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var showingEditDeck = false
    @State private var showingExport = false
    @State private var confirmingDeletion = false
    @State private var historyEntryPendingDeletion: UUID?
    @State private var confirmingHistoryReset = false
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
                if !deck.studyHistory.isEmpty {
                    studyHistorySection
                }
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
                .tint(.white)
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
            .tint(Theme.deckAccent(for: deck))
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
                .foregroundStyle(Theme.deckAccent(for: deck))
                .tint(Theme.deckAccent(for: deck))

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

    private var studyHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("study.history.title")
                    .font(.title2.bold())

                Spacer()

                Button(role: .destructive) {
                    confirmingHistoryReset = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer l’historique")
            }

            VStack(spacing: 0) {
                ForEach(Array(deck.studyHistory.prefix(5))) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(
                            systemName: entry.mode == .flashcards
                                ? "rectangle.stack"
                                : "checklist"
                        )
                        .foregroundStyle(Theme.deckAccent(for: deck))
                        .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.mode.title)
                                    .font(.headline)

                                Spacer()

                                Text(
                                    entry.completedAt.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Button(role: .destructive) {
                                    historyEntryPendingDeletion = entry.id
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Supprimer cette entrée")
                            }

                            Text(historySummary(entry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 12)
                    .alert(
                        "Supprimer cette entrée ?",
                        isPresented: Binding(
                            get: { historyEntryPendingDeletion == entry.id },
                            set: { isPresented in
                                if !isPresented {
                                    historyEntryPendingDeletion = nil
                                }
                            }
                        )
                    ) {
                        Button("Supprimer", role: .destructive) {
                            deleteHistoryEntry(entry.id)
                        }
                        Button("Annuler", role: .cancel) {}
                    } message: {
                        Text("Cette session sera supprimée de l’historique.")
                    }

                    if entry.id != deck.studyHistory.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                Theme.cardBackground,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
        }
        .confirmationDialog(
            "Effacer tout l’historique ?",
            isPresented: $confirmingHistoryReset,
            titleVisibility: .visible
        ) {
            Button("Effacer l’historique", role: .destructive) {
                clearStudyHistory()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les sessions enregistrées pour ce deck seront supprimées.")
        }
    }

    private func historySummary(_ entry: StudyHistoryEntry) -> String {
        let itemLabel = entry.mode == .flashcards
            ? L10n.cards(entry.itemCount)
            : L10n.questions(entry.itemCount)

        return L10n.format(
            "study.history.summary",
            itemLabel,
            Int64(entry.correctCount),
            Int64(entry.incorrectCount),
            Int64(entry.successRate)
        )
    }

    private func deleteHistoryEntry(_ id: UUID) {
        deck.removeStudyHistoryEntry(id: id)
        deck.updatedAt = .now
        historyEntryPendingDeletion = nil
        try? modelContext.save()
        HapticService.play(.selection)
    }

    private func clearStudyHistory() {
        deck.clearStudyHistory()
        deck.updatedAt = .now
        historyEntryPendingDeletion = nil
        try? modelContext.save()
        HapticService.play(.selection)
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
            .background(
                Theme.deckAccent(for: deck),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
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
