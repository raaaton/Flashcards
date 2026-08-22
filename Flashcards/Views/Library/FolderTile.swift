import SwiftUI

struct FolderTile: View {
    let name: String
    let systemImage: String
    let deckCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NeutralIconBadge(
                systemName: systemImage,
                size: 44,
                cornerRadius: 22,
                symbolSize: 22
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(L10n.decks(deckCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .leading)
        .padding(16)
        .background(Theme.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
        .contentShape(.rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
