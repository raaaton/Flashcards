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
        deck.folder.map { Color(folderHex: $0.colorHex) } ?? .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: folderIcon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
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
