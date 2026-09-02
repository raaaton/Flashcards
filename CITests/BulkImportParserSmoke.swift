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
        Your flashcards are ready for Kavi. Wait until the generation is fully complete, then copy the JSON block below and return to Kavi.

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
        precondition(prompt.contains("Kavi"))
        precondition(prompt.contains("\"flashcards\""))
        precondition(
            prompt.contains(
                "Wait until the generation is fully complete, then copy the JSON block below"
            )
        )

        do {
            _ = try ExternalAIFlashcardParser.parse(prompt)
            preconditionFailure("Prepared prompt must not be parseable as an AI result")
        } catch let error as ExternalAIFlashcardParserError {
            precondition(error == .invalidJSON)
        } catch {
            preconditionFailure("Unexpected error type for prepared prompt")
        }

        let combinedResponse = """
        Ready.
        ```json
        {
          "flashcards": [
            {"id":"fc-1","term":"Alpha","definition":"First"},
            {"id":"fc-2","term":"Beta","definition":"Second"}
          ],
          "tests": {
            "multipleChoice": [
              {"question":"Which is first?","choices":["Alpha","Beta"],"correctAnswer":"Alpha","sourceFlashcardID":"fc-1"},
              {"question":"Which is first?","choices":["Beta","Alpha"],"correctAnswer":"Alpha","sourceFlashcardID":"fc-1"},
              {"question":"What follows Alpha?","choices":["Beta","Gamma"],"correctAnswer":"Beta","sourceFlashcardID":"fc-1"}
            ],
            "trueFalse": [
              {"statement":"Beta is second.","correctAnswer":true,"sourceFlashcardID":"fc-2"}
            ]
          }
        }
        ```
        """
        let combined = try! ExternalAIAuthoredParser.parseCombined(combinedResponse)
        precondition(combined.cards.count == 2)
        precondition(combined.testConfiguration.mode == .ai)
        precondition(combined.testConfiguration.multipleChoice.count == 2)
        precondition(combined.testConfiguration.trueFalse.count == 1)
        precondition(
            combined.testConfiguration.multipleChoice[0].sourceCardID
                == combined.testConfiguration.multipleChoice[1].sourceCardID
        )

        let sourceCards = [
            ExternalAISourceCard(id: UUID(), term: "One", definition: "1"),
            ExternalAISourceCard(id: UUID(), term: "Two", definition: "2")
        ]
        let testsOnly = """
        {
          "tests": {
            "multipleChoice": [
              {"question":"Which number is one?","choices":["1","2"],"correctAnswer":"1","sourceFlashcardID":"fc-1"}
            ],
            "trueFalse": [
              {"statement":"Two is 2.","correctAnswer":true,"sourceFlashcardID":"fc-2"}
            ]
          }
        }
        """
        let testsOnlyConfiguration = try! ExternalAIAuthoredParser.parseTestsOnly(
            testsOnly,
            sourceCards: sourceCards
        )
        precondition(testsOnlyConfiguration.multipleChoice[0].sourceCardID == sourceCards[0].id)
        precondition(testsOnlyConfiguration.trueFalse[0].sourceCardID == sourceCards[1].id)

        let duplicateIDResponse = combinedResponse.replacingOccurrences(
            of: "\"id\":\"fc-2\"",
            with: "\"id\":\"fc-1\""
        )
        do {
            _ = try ExternalAIAuthoredParser.parseCombined(duplicateIDResponse)
            preconditionFailure("Duplicate flashcard IDs must fail")
        } catch ExternalAIAuthoredParserError.duplicateFlashcardID("fc-1") {
            // Expected.
        } catch {
            preconditionFailure("Unexpected duplicate flashcard ID error: \(error)")
        }

        let missingFlashcardID = combinedResponse.replacingOccurrences(
            of: "\"id\":\"fc-2\",",
            with: ""
        )
        do {
            _ = try ExternalAIAuthoredParser.parseCombined(missingFlashcardID)
            preconditionFailure("A missing flashcard ID must fail")
        } catch ExternalAIAuthoredParserError.missingFlashcardID {
            // Expected.
        } catch {
            preconditionFailure("Unexpected missing flashcard ID error: \(error)")
        }

        let missingReference = combinedResponse.replacingOccurrences(
            of: ",\"sourceFlashcardID\":\"fc-2\"",
            with: ""
        )
        do {
            _ = try ExternalAIAuthoredParser.parseCombined(missingReference)
            preconditionFailure("A missing source reference must fail")
        } catch ExternalAIAuthoredParserError.missingSourceFlashcardID {
            // Expected.
        } catch {
            preconditionFailure("Unexpected missing source error: \(error)")
        }

        let unknownReference = testsOnly.replacingOccurrences(
            of: "\"sourceFlashcardID\":\"fc-2\"",
            with: "\"sourceFlashcardID\":\"fc-99\""
        )
        do {
            _ = try ExternalAIAuthoredParser.parseTestsOnly(
                unknownReference,
                sourceCards: sourceCards
            )
            preconditionFailure("An unknown source reference must fail")
        } catch ExternalAIAuthoredParserError.unknownSourceFlashcardID("fc-99") {
            // Expected.
        } catch {
            preconditionFailure("Unexpected unknown source error: \(error)")
        }

        let duplicateChoices = testsOnly.replacingOccurrences(
            of: "[\"1\",\"2\"]",
            with: "[\"1\",\" 1 \"]"
        )
        do {
            _ = try ExternalAIAuthoredParser.parseTestsOnly(
                duplicateChoices,
                sourceCards: sourceCards
            )
            preconditionFailure("Normalized duplicate choices must fail")
        } catch ExternalAIAuthoredParserError.invalidMultipleChoice(0) {
            // Expected.
        } catch {
            preconditionFailure("Unexpected duplicate-choice error: \(error)")
        }

        let missingCorrectAnswer = testsOnly.replacingOccurrences(
            of: ",\"correctAnswer\":\"1\"",
            with: ""
        )
        do {
            _ = try ExternalAIAuthoredParser.parseTestsOnly(
                missingCorrectAnswer,
                sourceCards: sourceCards
            )
            preconditionFailure("A missing correct answer must fail")
        } catch {
            // Any parse/validation failure is correct for a missing required field.
        }

        let incompletePools = testsOnly.replacingOccurrences(
            of: "{\"statement\":\"Two is 2.\",\"correctAnswer\":true,\"sourceFlashcardID\":\"fc-2\"}",
            with: ""
        )
        do {
            _ = try ExternalAIAuthoredParser.parseTestsOnly(
                incompletePools,
                sourceCards: sourceCards
            )
            preconditionFailure("AI import must require both question pools")
        } catch {
            // Expected.
        }

        let contradictory = combinedResponse.replacingOccurrences(
            of: "{\"question\":\"What follows Alpha?\",\"choices\":[\"Beta\",\"Gamma\"],\"correctAnswer\":\"Beta\",\"sourceFlashcardID\":\"fc-1\"}",
            with: "{\"question\":\"Which is first?\",\"choices\":[\"Alpha\",\"Beta\"],\"correctAnswer\":\"Beta\",\"sourceFlashcardID\":\"fc-1\"}"
        )
        do {
            _ = try ExternalAIAuthoredParser.parseCombined(contradictory)
            preconditionFailure("Contradictory duplicates must fail")
        } catch ExternalAIAuthoredParserError.contradictoryQuestion {
            // Expected.
        } catch {
            preconditionFailure("Unexpected contradictory-question error: \(error)")
        }

        let combinedPrompt = ExternalAIFlashcardPromptBuilder.makeCombinedPrompt(
            deckName: "History"
        )
        precondition(combinedPrompt.contains("EVERY distinct explicit definition"))
        precondition(combinedPrompt.contains("sourceFlashcardID"))
        precondition(combinedPrompt.contains("Multiple questions may reference the same flashcard"))
        precondition(combinedPrompt.contains("Your flashcards and tests are ready for Kavi"))
        let testsPrompt = ExternalAIFlashcardPromptBuilder.makeTestsOnlyPrompt(
            deckName: "Numbers",
            cards: sourceCards
        )
        precondition(testsPrompt.contains("\"id\" : \"fc-1\""))
        precondition(testsPrompt.contains("Your tests are ready for Kavi"))

        precondition(
            ExternalAIProvider.allCases == [.claude, .chatGPT, .gemini]
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

        let languageKey = "settings.language"
        let previousLanguage = UserDefaults.standard.object(forKey: languageKey)
        let duplicateSuffixes = [
            "french": "copie",
            "english": "copy",
            "german": "Kopie",
            "spanish": "copia"
        ]
        for (language, suffix) in duplicateSuffixes {
            UserDefaults.standard.set(language, forKey: languageKey)
            precondition(L10n.text("library.duplicate_suffix") == suffix)
        }
        if let previousLanguage {
            UserDefaults.standard.set(previousLanguage, forKey: languageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: languageKey)
        }

        print("BulkImportParser smoke tests passed")
    }
}
