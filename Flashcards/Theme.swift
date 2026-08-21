import SwiftUI

@MainActor
enum Theme {
    static let accent = Color.blue
    static let cardBackground = Color(uiColor: .secondarySystemBackground)

    static func deckAccent(for deck: Deck) -> Color {
        deck.folder.map { Color(folderHex: $0.colorHex) } ?? accent
    }
}

@MainActor
extension View {
    func neutralIconColor() -> some View {
        foregroundStyle(Color.white)
            .tint(Color.white)
    }

    func normalActionColor(_ color: Color = Theme.accent) -> some View {
        foregroundStyle(color)
            .tint(color)
    }

    func destructiveActionColor() -> some View {
        foregroundStyle(Color.red)
            .tint(Color.red)
    }
}

struct PrimaryStartButton: View {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let accent: Color
    let action: () -> Void

    init(
        title: LocalizedStringKey = "common.start",
        isEnabled: Bool = true,
        accent: Color = Theme.accent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button {
            HapticService.play(.selection)
            action()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(accent, in: .rect(cornerRadius: 16, style: .continuous))
                .contentShape(.rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct CircularSaveButton: View {
    let accent: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "checkmark")
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(accent, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel("Enregistrer")
    }
}

struct DeckProgressBar: View {
    let deckName: String
    let masteredCount: Int
    let totalCount: Int
    let accent: Color

    private var progress: Double {
        guard totalCount > 0 else { return 0 }

        return min(
            max(Double(masteredCount) / Double(totalCount), 0),
            1
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progression")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(masteredCount) / \(totalCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.20))

                    Capsule()
                        .fill(accent.gradient)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
            .animation(.snappy(duration: 0.35), value: progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.format("deck.progress.label", deckName)
        )
        .accessibilityValue(
            L10n.format(
                "deck.progress.value",
                Int64(masteredCount),
                Int64(totalCount)
            )
        )
    }
}

struct CardEditorSurface: View {
    @Binding var term: String
    @Binding var definition: String

    var body: some View {
        VStack(spacing: 0) {
            editorField(
                title: "Terme",
                placeholder: "Saisissez le terme",
                text: $term,
                minHeight: 42,
                lineLimits: 1...2
            )

            Divider()
                .padding(.leading, 18)

            editorField(
                title: "Définition",
                placeholder: "Saisissez la définition",
                text: $definition,
                minHeight: 88,
                lineLimits: 2...8
            )
        }
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: .rect(cornerRadius: 12, style: .continuous)
        )
    }

    private func editorField(
        title: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        minHeight: CGFloat,
        lineLimits: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(
                placeholder,
                text: text,
                axis: .vertical
            )
            .font(.body)
            .lineLimit(lineLimits)
            .textInputAutocapitalization(.sentences)
            .frame(
                minHeight: minHeight,
                alignment: .topLeading
            )
        }
        .padding(18)
    }
}

struct StudyDirectionMenu: View {
    @Binding var selection: StudyDirection
    let accent: Color

    init(selection: Binding<StudyDirection>, accent: Color = Theme.accent) {
        _selection = selection
        self.accent = accent
    }

    var body: some View {
        Menu {
            Picker("Sens", selection: $selection) {
                ForEach(StudyDirection.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selection.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
        }
        .normalActionColor(accent)
        .accessibilityLabel("Sens")
        .accessibilityValue(selection.title)
    }
}


private struct ConcentricFloatingActionModifier<FloatingContent: View>: ViewModifier {
    let floatingContent: FloatingContent

    private let diameter: CGFloat = 62
    private let fallbackEdgeMargin: CGFloat = 16

    // Correction optique : un cercle paraît mieux légèrement
    // plus à l'intérieur que le centre géométrique du coin.
    private let inwardOffset: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let corner = geometry.containerCornerInsets.bottomTrailing
                    let minimumCenterInset =
                        (diameter / 2) + fallbackEdgeMargin

                    let horizontalInset =
                        max(corner.width, minimumCenterInset)
                        + inwardOffset

                    let verticalInset =
                        max(corner.height, minimumCenterInset)
                        + inwardOffset

                    floatingContent
                        .position(
                            x: geometry.size.width - horizontalInset,
                            y: geometry.size.height - verticalInset
                        )
                }
                .ignoresSafeArea(
                    .container,
                    edges: [.bottom, .trailing]
                )
            }
    }
}

extension View {
    func concentricFloatingAction<FloatingContent: View>(
        @ViewBuilder content: () -> FloatingContent
    ) -> some View {
        modifier(
            ConcentricFloatingActionModifier(
                floatingContent: content()
            )
        )
    }
}
