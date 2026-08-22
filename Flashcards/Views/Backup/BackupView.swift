import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.createdAt) private var folders: [Folder]
    @Query(sort: \Deck.createdAt) private var decks: [Deck]

    let deck: Deck?
    let autoOpenImporter: Bool

    @State private var exportURL: URL?
    @State private var showingFileImporter = false
    @State private var didAutoOpenImporter = false
    @State private var pendingEnvelope: BackupEnvelopeV1?
    @State private var statusTitle = ""
    @State private var statusMessage = ""
    @State private var showingStatus = false

    init(deck: Deck? = nil, autoOpenImporter: Bool = false) {
        self.deck = deck
        self.autoOpenImporter = autoOpenImporter
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label(
                                deck == nil
                                    ? L10n.text("backup.share.database")
                                    : L10n.text("backup.share.deck"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .normalActionColor()
                    } else {
                        HStack {
                            ProgressView()
                            Text("Préparation du fichier JSON…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let deck {
                        LabeledContent("Contenu", value: L10n.cards(deck.cards.count))
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
                        .normalActionColor()
                    } header: {
                        Text("Importer")
                    } footer: {
                        Text("L’import fusionne les éléments par identifiant sans supprimer le contenu local absent du fichier.")
                    }
                }
            }
            .navigationTitle(
                deck == nil
                    ? L10n.text("backup.title")
                    : L10n.text("backup.export_deck.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            .task {
                prepareExport()

                if autoOpenImporter && deck == nil && !didAutoOpenImporter {
                    didAutoOpenImporter = true
                    await Task.yield()
                    showingFileImporter = true
                }
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
                .normalActionColor()
            Button("Annuler", role: .cancel) { pendingEnvelope = nil }
                .normalActionColor()
        } message: {
            if let pendingEnvelope {
                Text(L10n.format(
                    "backup.merge.preview",
                    Int64(pendingEnvelope.folders.count),
                    Int64(pendingEnvelope.decks.count),
                    Int64(pendingEnvelope.decks.reduce(0) { $0 + $1.cards.count })
                ))
            }
        }
        .alert(statusTitle, isPresented: $showingStatus) {
            Button("OK", role: .cancel) {}
                .normalActionColor()
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
            showStatus(title: L10n.text("backup.export.failed"), message: error.localizedDescription)
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
            showStatus(title: L10n.text("backup.import.failed"), message: error.localizedDescription)
        }
    }

    private func importPendingEnvelope() {
        guard let envelope = pendingEnvelope else { return }
        pendingEnvelope = nil
        do {
            let report = try BackupService.importEnvelope(envelope, into: modelContext)
            prepareExport()
            showStatus(title: L10n.text("backup.import.complete"), message: report.summary)
        } catch {
            showStatus(title: L10n.text("backup.import.failed"), message: error.localizedDescription)
        }
    }

    private func showStatus(title: String, message: String) {
        statusTitle = title
        statusMessage = message
        showingStatus = true
    }
}
