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
                Text("\(deck.cards.count) carte\(deck.cards.count > 1 ? "s" : "")")
                Spacer()
                Text("\(Int(progress * 100)) %")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ProgressView(value: progress)
                .accessibilityLabel("Progression de \(deck.name)")
                .accessibilityValue("\(masteredCount) cartes maîtrisées sur \(deck.cards.count)")
        }
        .padding(.vertical, 4)
    }
}
