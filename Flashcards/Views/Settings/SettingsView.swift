import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("settings.language.section") {
                    Picker("settings.language.label", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(LocalizedStringKey(language.titleKey)).tag(language)
                        }
                    }
                }

                Section("settings.accent.section") {
                    HStack(spacing: 12) {
                        ForEach(FolderAppearance.presetColors, id: \.self) { preset in
                            Button {
                                settings.accentHex = preset
                            } label: {
                                Circle()
                                    .fill(Color(folderHex: preset))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if settings.accentHex.caseInsensitiveCompare(preset) == .orderedSame {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("settings.accent.preset")
                            .accessibilityAddTraits(
                                settings.accentHex.caseInsensitiveCompare(preset) == .orderedSame
                                    ? .isSelected
                                    : []
                            )
                        }
                    }

                    ColorPicker(
                        "settings.accent.custom",
                        selection: Binding(
                            get: { settings.accentColor },
                            set: { settings.accentHex = $0.folderHexString }
                        ),
                        supportsOpacity: false
                    )

                    Button("settings.accent.reset", systemImage: "arrow.counterclockwise") {
                        settings.resetAccent()
                    }
                }

                Section("settings.feedback.section") {
                    Toggle("settings.haptics", isOn: $settings.hapticsEnabled)
                    Toggle("settings.celebrations", isOn: $settings.celebrationsEnabled)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}
