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

    var body: some View {
        NavigationStack {
            Form {
                Section("Dossier") {
                    HStack(spacing: 14) {
                        Image(systemName: iconName)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Color(folderHex: colorHex).gradient, in: .circle)

                        TextField("Nom du dossier", text: $name)
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
                                    .foregroundStyle(iconName == symbol ? .white : .secondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        iconName == symbol ? Color(folderHex: colorHex) : .clear,
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
                    }

                    ColorPicker("Couleur personnalisée", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { _, newColor in
                            colorHex = newColor.folderHexString
                        }
                }
            }
            .navigationTitle(folder == nil ? "Nouveau dossier" : "Modifier le dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(cleanName.isEmpty)
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
