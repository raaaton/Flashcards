import SwiftUI

@MainActor
enum Theme {
    static let accent = Color.blue
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
}

@MainActor
extension View {
    func neutralIconColor() -> some View {
        foregroundStyle(Color.white)
            .tint(Color.white)
    }

    func normalActionColor() -> some View {
        foregroundStyle(Theme.accent)
            .tint(Theme.accent)
    }

    func destructiveActionColor() -> some View {
        foregroundStyle(Color.red)
            .tint(Color.red)
    }
}

struct PrimaryStartButton: View {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let action: () -> Void

    init(
        title: LocalizedStringKey = "common.start",
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
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
                .background(Theme.accent, in: .rect(cornerRadius: 16, style: .continuous))
                .contentShape(.rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct StudyDirectionMenu: View {
    @Binding var selection: StudyDirection

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
        .normalActionColor()
        .accessibilityLabel("Sens")
        .accessibilityValue(selection.title)
    }
}
