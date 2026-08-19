import SwiftData
import SwiftUI

struct FolderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let folder: Folder?
    @State private var name: String

    init(folder: Folder? = nil) {
        self.folder = folder
        _name = State(initialValue: folder?.name ?? "")
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du dossier", text: $name)
                    .textInputAutocapitalization(.sentences)
            }
            .navigationTitle(folder == nil ? "Nouveau dossier" : "Renommer")
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
        } else {
            modelContext.insert(Folder(name: cleanName))
        }
        try? modelContext.save()
        dismiss()
    }
}
