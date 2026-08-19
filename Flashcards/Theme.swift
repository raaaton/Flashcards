import SwiftUI

@MainActor
enum Theme {
    static let accent = Color(folderHex: "5856D6")
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
}

struct PrimaryStartButton: View {
    let isEnabled: Bool
    let action: () -> Void

    init(isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            HapticService.play(.selection)
            action()
        } label: {
            Text("common.start")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accent, in: .rect(cornerRadius: 16, style: .continuous))
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
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel("Sens")
        .accessibilityValue(selection.title)
    }
}
