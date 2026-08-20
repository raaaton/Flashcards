import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var showingBackup = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("settings.study.section") {
                    Toggle("settings.haptics", isOn: $settings.hapticsEnabled)
                    Toggle("settings.celebrations", isOn: $settings.celebrationsEnabled)
                }

                Section("settings.search.section") {
                    Toggle("settings.search.scope", isOn: $settings.searchScopeEnabled)
                }

                Section("settings.language.section") {
                    Picker("settings.language.label", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(LocalizedStringKey(language.titleKey)).tag(language)
                        }
                    }
                }

                Section("settings.data.section") {
                    Button("settings.backup", systemImage: "externaldrive") {
                        showingBackup = true
                    }
                    .normalActionColor()
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
        .sheet(isPresented: $showingBackup) {
            BackupView()
        }
    }
}
