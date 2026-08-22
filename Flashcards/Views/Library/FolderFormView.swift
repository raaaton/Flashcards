import SwiftData
import SwiftUI

struct FolderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let folder: Folder?
    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String
    @State private var customColor: Color
    @FocusState private var nameFieldFocused: Bool

    init(folder: Folder? = nil) {
        self.folder = folder
        _name = State(initialValue: folder?.name ?? "")
        let initialIcon = folder?.iconName ?? FolderAppearance.defaultIcon
        let initialColor = folder?.colorHex ?? FolderAppearance.defaultColorHex
        _iconName = State(initialValue: initialIcon)
        _colorHex = State(initialValue: initialColor)
        _customColor = State(initialValue: Color(folderHex: initialColor))
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var accent: Color {
        Theme.accent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dossier") {
                    HStack(spacing: 14) {
                        Image(systemName: iconName)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Theme.foreground(on: accent))
                            .frame(width: 52, height: 52)
                            .background(accent.gradient, in: .circle)

                        TextField("Nom du dossier", text: $name)
                            .focused($nameFieldFocused)
                            .task {
                                guard folder == nil else { return }
                                try? await Task.sleep(nanoseconds: 120_000_000)
                                nameFieldFocused = true
                            }
                            .textInputAutocapitalization(.sentences)
                    }
                }

                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(FolderAppearance.icons, id: \.self) { symbol in
                            Button {
                                iconName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(
                                        iconName == symbol
                                            ? Theme.foreground(on: accent)
                                            : Color.primary
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        iconName == symbol ? accent : .clear,
                                        in: .rect(cornerRadius: 12, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                            .accessibilityAddTraits(iconName == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Couleur") {
                    HStack(spacing: 12) {
                        ForEach(FolderAppearance.presetColors, id: \.self) { preset in
                            Button {
                                colorHex = preset
                                customColor = Color(folderHex: preset)
                            } label: {
                                Circle()
                                    .fill(Color(folderHex: preset))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if colorHex.caseInsensitiveCompare(preset) == .orderedSame {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Couleur")
                            .accessibilityAddTraits(
                                colorHex.caseInsensitiveCompare(preset) == .orderedSame ? .isSelected : []
                            )
                        }

                        ColorPicker(
                            "",
                            selection: $customColor,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 28, height: 28)
                        .accessibilityLabel("Couleur personnalisée")
                        .onChange(of: customColor) { _, newColor in
                            colorHex = newColor.folderHexString
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(
                folder == nil
                    ? L10n.text("folder.new.title")
                    : L10n.text("folder.edit.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .tint(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    CircularSaveButton(
                        accent: accent,
                        isEnabled: !cleanName.isEmpty
                    ) {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        if let folder {
            folder.name = cleanName
            folder.iconName = iconName
            folder.colorHex = colorHex
        } else {
            modelContext.insert(
                Folder(name: cleanName, iconName: iconName, colorHex: colorHex)
            )
        }
        try? modelContext.save()
        dismiss()
    }
}
