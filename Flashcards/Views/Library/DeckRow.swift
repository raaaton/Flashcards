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
