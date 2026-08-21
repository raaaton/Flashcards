import Foundation
import SwiftData

@Model
final class Deck {
    var id: UUID
    var name: String
    var deckDescription: String?
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?
    var completedStudySessions: Int = 0
    var activeStudySessionData: Data?
    var studyHistoryData: Data?
    var lastStudyActivityAt: Date?
    var isPinned: Bool = false
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Card.deck)
    var cards: [Card]

    init(name: String, folder: Folder? = nil) {
        id = UUID()
        self.name = name
        deckDescription = nil
        createdAt = .now
        updatedAt = .now
        lastOpenedAt = nil
        completedStudySessions = 0
        activeStudySessionData = nil
        studyHistoryData = nil
        lastStudyActivityAt = nil
        isPinned = false
        self.folder = folder
        cards = []
    }
}

enum StudyHistoryMode: String, Codable, Equatable, Sendable {
    case flashcards
    case test

    var title: String {
        switch self {
        case .flashcards: "Flashcards"
        case .test: "Test"
        }
    }
}

struct StudyHistoryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let completedAt: Date
    let mode: StudyHistoryMode
    let itemCount: Int
    let correctCount: Int
    let incorrectCount: Int

    var successRate: Int {
        guard itemCount > 0 else { return 0 }
        return Int((Double(correctCount) / Double(itemCount) * 100).rounded())
    }
}

extension Deck {
    var studyHistory: [StudyHistoryEntry] {
        guard let studyHistoryData else { return [] }
        return (try? JSONDecoder().decode([StudyHistoryEntry].self, from: studyHistoryData)) ?? []
    }

    func recordCompletedSession(
        mode: StudyHistoryMode,
        itemCount: Int,
        correctCount: Int,
        incorrectCount: Int
    ) {
        guard itemCount > 0 else { return }

        let entry = StudyHistoryEntry(
            id: UUID(),
            completedAt: .now,
            mode: mode,
            itemCount: itemCount,
            correctCount: correctCount,
            incorrectCount: incorrectCount
        )

        setStudyHistory(Array(([entry] + studyHistory).prefix(5)))
    }

    func removeStudyHistoryEntry(id: UUID) {
        setStudyHistory(
            studyHistory.filter { $0.id != id }
        )
    }

    func clearStudyHistory() {
        studyHistoryData = nil
    }

    private func setStudyHistory(_ entries: [StudyHistoryEntry]) {
        guard !entries.isEmpty else {
            studyHistoryData = nil
            return
        }

        studyHistoryData = try? JSONEncoder().encode(entries)
    }
}
