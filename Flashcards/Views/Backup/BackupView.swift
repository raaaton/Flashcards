import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.createdAt) private var folders: [Folder]
    @Query(sort: \Deck.createdAt) private var decks: [Deck]

    let deck: Deck?

    @State private var exportURL: URL?
    @State private var showingFileImporter = false
    @State private var pendingEnvelope: BackupEnvelopeV1?
    @State private var statusTitle = ""
    @State private var statusMessage = ""
    @State private var showingStatus = false

    init(deck: Deck? = nil) {
        self.deck = deck
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label(
                                deck == nil ? "Partager toute la base" : "Partager ce deck",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    } else {
                        HStack {
                            ProgressView()
                            Text("Préparation du fichier JSON…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let deck {
                        LabeledContent("Contenu", value: "\(deck.cards.count) carte\(deck.cards.count > 1 ? "s" : "")")
                    } else {
                        LabeledContent("Decks", value: "\(decks.count)")
                        LabeledContent("Cartes", value: "\(decks.reduce(0) { $0 + $1.cards.count })")
                    }
                } header: {
                    Text("Exporter")
                } footer: {
                    Text("Le fichier contient le texte, les dossiers, l’ordre et les statistiques de progression.")
                }

                if deck == nil {
                    Section {
                        Button("Choisir un fichier JSON", systemImage: "doc.badge.plus") {
                            showingFileImporter = true
                        }
                    } header: {
                        Text("Importer")
                    } footer: {
                        Text("L’import fusionne les éléments par identifiant sans supprimer le contenu local absent du fichier.")
                    }
                }
            }
            .navigationTitle(deck == nil ? "Sauvegarde" : "Exporter le deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            .task {
                prepareExport()
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json]
            ) { result in
                loadImport(result)
            }
        }
        .alert("Fusionner cette sauvegarde ?", isPresented: pendingBinding) {
            Button("Importer") { importPendingEnvelope() }
            Button("Annuler", role: .cancel) { pendingEnvelope = nil }
        } message: {
            if let pendingEnvelope {
                Text(
                    "\(pendingEnvelope.folders.count) dossier\(pendingEnvelope.folders.count > 1 ? "s" : ""), "
                        + "\(pendingEnvelope.decks.count) deck\(pendingEnvelope.decks.count > 1 ? "s" : "") et "
                        + "\(pendingEnvelope.decks.reduce(0) { $0 + $1.cards.count }) cartes seront fusionnés."
                )
            }
        }
        .alert(statusTitle, isPresented: $showingStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
    }

    private var pendingBinding: Binding<Bool> {
        Binding(
            get: { pendingEnvelope != nil },
            set: { if !$0 { pendingEnvelope = nil } }
        )
    }

    private func prepareExport() {
        do {
            let envelope: BackupEnvelopeV1
            let name: String
            if let deck {
                envelope = BackupService.deckEnvelope(deck)
                name = deck.name
            } else {
                envelope = BackupService.databaseEnvelope(folders: folders, decks: decks)
                name = "Flashcards-backup"
            }
            exportURL = try BackupService.temporaryJSONFile(for: envelope, suggestedName: name)
        } catch {
            showStatus(title: "Export impossible", message: error.localizedDescription)
        }
    }

    private func loadImport(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            pendingEnvelope = try BackupCodec.decode(Data(contentsOf: url))
        } catch {
            showStatus(title: "Import impossible", message: error.localizedDescription)
        }
    }

    private func importPendingEnvelope() {
        guard let envelope = pendingEnvelope else { return }
        pendingEnvelope = nil
        do {
            let report = try BackupService.importEnvelope(envelope, into: modelContext)
            prepareExport()
            showStatus(title: "Import terminé", message: report.summary)
        } catch {
            showStatus(title: "Import impossible", message: error.localizedDescription)
        }
    }

    private func showStatus(title: String, message: String) {
        statusTitle = title
        statusMessage = message
        showingStatus = true
    }
}
