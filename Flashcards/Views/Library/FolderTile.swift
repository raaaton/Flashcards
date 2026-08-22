import SwiftUI

struct FolderTile: View {
    let name: String
    let systemImage: String
    let color: Color
    let deckCount: Int
    let showsMintGradient: Bool

    init(
        name: String,
        systemImage: String,
        color: Color,
        deckCount: Int,
        showsMintGradient: Bool = true
    ) {
        self.name = name
        self.systemImage = systemImage
        self.color = color
        self.deckCount = deckCount
        self.showsMintGradient = showsMintGradient
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.10), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(L10n.decks(deckCount))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.accent.opacity(0.075))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06))
        }
        .contentShape(.rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
