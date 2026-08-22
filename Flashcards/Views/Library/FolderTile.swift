import SwiftUI

struct FolderTile: View {
    let name: String
    let systemImage: String
    let deckCount: Int

    private var iconColor: Color {
        AppAccent.mint.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.foreground(on: iconColor))
                .frame(width: 44, height: 44)
                .background(iconColor.gradient, in: .circle)

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
        .compositingGroup()
        .contentShape(.dragPreview, .rect(cornerRadius: 22, style: .continuous))
        .contentShape(.rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
