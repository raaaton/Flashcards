import Foundation

@main
enum BulkImportParserSmoke {
    static func main() {
        let fiftyLines = (1...60)
            .map { "Terme \($0): Définition \($0)" }
            .joined(separator: "\n")
        let colonResult = BulkImportParser.parse(
            BulkImportInput(text: fiftyLines, termDelimiter: ":", cardDelimiter: "\n")
        )
        precondition(colonResult.cards.count == 60)
        precondition(colonResult.invalidRecords.isEmpty)

        let mixed = " Alpha , Première définition ;invalide; Beta , Seconde, avec virgule ; , vide"
        let commaResult = BulkImportParser.parse(
            BulkImportInput(text: mixed, termDelimiter: ",", cardDelimiter: ";")
        )
        precondition(commaResult.cards.count == 2)
        precondition(commaResult.cards[0].term == "Alpha")
        precondition(commaResult.cards[1].definition == "Seconde, avec virgule")
        precondition(commaResult.invalidRecords.count == 2)

        let customResult = BulkImportParser.parse(
            BulkImportInput(text: "un => one|||deux => two", termDelimiter: "=>", cardDelimiter: "|||")
        )
        precondition(customResult.cards.map(\.term) == ["un", "deux"])

        let blankResult = BulkImportParser.parse(
            BulkImportInput(text: "\n\n", termDelimiter: ":", cardDelimiter: "\n")
        )
        precondition(blankResult.cards.isEmpty)
        precondition(blankResult.ignoredEmptyRecords == 3)

        let duplicateCandidates = BulkImportParser.parse(
            BulkImportInput(
                text: "  Paris : France\nPARIS:france\nParis:Texas\nLyon:France\nLyon:France",
                termDelimiter: ":",
                cardDelimiter: "\n"
            )
        ).cards
        let duplicates = BulkDuplicateDetector.analyze(
            candidates: duplicateCandidates,
            existingCards: [(term: "paris", definition: "FRANCE")]
        )
        precondition(duplicates.exactCount == 3)
        precondition(duplicates.possibleCount == 1)
        precondition(duplicates.kind(for: 0) == .exact)
        precondition(duplicates.kind(for: 2) == .possible)
        precondition(duplicates.kind(for: 4) == .exact)

        let internalOnly = BulkDuplicateDetector.analyze(
            candidates: [
                ParsedCard(recordIndex: 0, term: "Un", definition: "One"),
                ParsedCard(recordIndex: 1, term: "un", definition: "one")
            ],
            existingCards: []
        )
        precondition(internalOnly.exactRecordIndexes == [1])

        let aiResponse = """
        Your flashcards are ready for Flashcards. Copy the JSON block below, then return to Flashcards.

        ```json
        {
          "flashcards": [
            {
              "term": "Ratio 2:1",
              "definition": "Two units for one; the colon remains valid JSON content."
            },
            {
              "term": "Second concept",
              "definition": "A concise answer with punctuation, commas, and: colons."
            }
          ]
        }
        ```
        """
        let aiCards = try! ExternalAIFlashcardParser.parse(aiResponse)
        precondition(aiCards.count == 2)
        precondition(aiCards[0].term == "Ratio 2:1")
        precondition(aiCards[0].definition.contains("colon remains"))
        precondition(aiCards[1].recordIndex == 1)

        let firstImportSession = ExternalAIImportSession(cards: aiCards)
        let repeatedAICards = try! ExternalAIFlashcardParser.parse(aiResponse)
        let secondImportSession = ExternalAIImportSession(cards: repeatedAICards)
        precondition(repeatedAICards == aiCards)
        precondition(firstImportSession.cards == aiCards)
        precondition(secondImportSession.cards == aiCards)
        precondition(firstImportSession.id != secondImportSession.id)

        let bareArray = """
        [
          {"term":"  Alpha  ","definition":"  First answer  "},
          {"term":"Beta","definition":"Second answer"}
        ]
        """
        let bareArrayCards = try! ExternalAIFlashcardParser.parse(bareArray)
        precondition(bareArrayCards.map(\.term) == ["Alpha", "Beta"])
        precondition(bareArrayCards[0].definition == "First answer")

        do {
            _ = try ExternalAIFlashcardParser.parse(
                "{\"flashcards\":[{\"term\":\"Only a term\",\"definition\":\"   \"}]}"
            )
            preconditionFailure("Incomplete AI flashcard should fail")
        } catch let error as ExternalAIFlashcardParserError {
            precondition(error == .incompleteRecord(0))
        } catch {
            preconditionFailure("Unexpected error type for incomplete AI flashcard")
        }

        do {
            _ = try ExternalAIFlashcardParser.parse("{\"flashcards\":[]}")
            preconditionFailure("Empty AI result should fail")
        } catch let error as ExternalAIFlashcardParserError {
            precondition(error == .emptyResult)
        } catch {
            preconditionFailure("Unexpected error type for empty AI result")
        }

        let prompt = ExternalAIFlashcardPromptBuilder.makePrompt(deckName: "History: 1848")
        precondition(prompt.contains("History: 1848"))
        precondition(prompt.contains("\"flashcards\""))
        precondition(prompt.contains("Copy the JSON block below"))

        do {
            _ = try ExternalAIFlashcardParser.parse(prompt)
            preconditionFailure("Prepared prompt must not be parseable as an AI result")
        } catch let error as ExternalAIFlashcardParserError {
            precondition(error == .invalidJSON)
        } catch {
            preconditionFailure("Unexpected error type for prepared prompt")
        }

        precondition(
            ExternalAIProvider.allCases == [.gemini, .claude, .chatGPT]
        )

        let handoffPrompt = "Line 1\nLine 2 & 50% = yes? emoji 🤖 / colon:"
        let chatGPTCandidates = ExternalAIProvider.chatGPT.nativeLaunchCandidates(
            for: handoffPrompt
        )
        precondition(chatGPTCandidates.count == 6)

        let chatGPTQ = URLComponents(
            url: chatGPTCandidates[0],
            resolvingAgainstBaseURL: false
        )!
        precondition(chatGPTQ.scheme == "chatgpt")
        precondition(chatGPTQ.host == "chat.openai.com")
        precondition(chatGPTQ.queryItems?.first?.name == "q")
        precondition(chatGPTQ.queryItems?.first?.value == handoffPrompt)
        precondition(chatGPTCandidates[0].absoluteString.contains("%0A"))

        let chatGPTPrompt = URLComponents(
            url: chatGPTCandidates[1],
            resolvingAgainstBaseURL: false
        )!
        precondition(chatGPTPrompt.queryItems?.first?.name == "prompt")
        precondition(chatGPTPrompt.queryItems?.first?.value == handoffPrompt)
        precondition(chatGPTCandidates[2].host == "chatgpt.com")
        precondition(chatGPTCandidates[4].absoluteString == "chatgpt://chatgpt.com/")
        precondition(chatGPTCandidates[5].scheme == "chatgpt")

        let claudeCandidates = ExternalAIProvider.claude.nativeLaunchCandidates(
            for: handoffPrompt
        )
        precondition(claudeCandidates.count == 1)
        precondition(claudeCandidates[0].absoluteString == "claude://")

        let geminiCandidates = ExternalAIProvider.gemini.nativeLaunchCandidates(
            for: handoffPrompt
        )
        precondition(geminiCandidates.count == 1)
        precondition(geminiCandidates[0].absoluteString == "googlegemini://")

        precondition(ExternalAIProvider.chatGPT.webURL.host == "chatgpt.com")
        precondition(ExternalAIProvider.claude.webURL.host == "claude.ai")
        precondition(ExternalAIProvider.gemini.webURL.host == "gemini.google.com")

        print("BulkImportParser smoke tests passed")
    }
}
