import Foundation

enum L10n {
    private static var locale: Locale {
        switch UserDefaults.standard.string(forKey: "settings.language") {
        case "french":
            Locale(identifier: "fr")
        case "english":
            Locale(identifier: "en")
        case "german":
            Locale(identifier: "de")
        case "spanish":
            Locale(identifier: "es")
        default:
            Locale.autoupdatingCurrent
        }
    }

    private static var languageCode: String {
        locale.language.languageCode?.identifier ?? "en"
    }

    private static let inlineTranslations: [String: [String: String]] = [
        "duplicate.label.exact": [
            "fr": "Doublon exact",
            "en": "Exact duplicate",
            "de": "Exaktes Duplikat",
            "es": "Duplicado exacto"
        ],
        "duplicate.label.possible": [
            "fr": "Doublon possible",
            "en": "Possible duplicate",
            "de": "Mögliches Duplikat",
            "es": "Duplicado posible"
        ],
        "duplicate.action.create_anyway": [
            "fr": "Créer quand même",
            "en": "Create Anyway",
            "de": "Trotzdem erstellen",
            "es": "Crear de todos modos"
        ],
        "duplicate.action.add_anyway": [
            "fr": "Ajouter quand même",
            "en": "Add Anyway",
            "de": "Trotzdem hinzufügen",
            "es": "Añadir de todos modos"
        ],
        "duplicate.action.save_anyway": [
            "fr": "Enregistrer quand même",
            "en": "Save Anyway",
            "de": "Trotzdem speichern",
            "es": "Guardar de todos modos"
        ],
        "ai.creation.method.title": [
            "fr": "Comment veux-tu créer les flashcards ?",
            "en": "How do you want to create the flashcards?",
            "de": "Wie möchtest du die Flashcards erstellen?",
            "es": "¿Cómo quieres crear las tarjetas?"
        ],
        "ai.creation.test_method.title": [
            "fr": "Comment veux-tu créer les tests (QCM, Vrai / Faux) ?",
            "en": "How do you want to create the tests (Multiple Choice, True / False)?",
            "de": "Wie möchtest du die Tests (Multiple Choice, Wahr / Falsch) erstellen?",
            "es": "¿Cómo quieres crear los tests (opción múltiple, verdadero / falso)?"
        ],
        "ai.test.use_flashcards": [
            "fr": "Utiliser les flashcards",
            "en": "Use flashcards",
            "de": "Flashcards verwenden",
            "es": "Usar las tarjetas"
        ],
        "ai.create.with_ai": [
            "fr": "Créer avec l’IA",
            "en": "Create with AI",
            "de": "Mit KI erstellen",
            "es": "Crear con IA"
        ],
        "ai.create.manual": [
            "fr": "Créer manuellement",
            "en": "Create manually",
            "de": "Manuell erstellen",
            "es": "Crear manualmente"
        ],
        "ai.recommended": [
            "fr": "Recommandé",
            "en": "Recommended",
            "de": "Empfohlen",
            "es": "Recomendado"
        ],
        "ai.continue": [
            "fr": "Continuer",
            "en": "Continue",
            "de": "Weiter",
            "es": "Continuar"
        ],
        "ai.back": [
            "fr": "Retour",
            "en": "Back",
            "de": "Zurück",
            "es": "Atrás"
        ],
        "ai.provider.title": [
            "fr": "Choisis ton IA",
            "en": "Choose your AI",
            "de": "Wähle deine KI",
            "es": "Elige tu IA"
        ],
        "ai.provider.subtitle": [
            "fr": "Kavi prépare le prompt. Tes documents restent entre toi et le service que tu choisis.",
            "en": "Kavi prepares the prompt. Your documents stay between you and the service you choose.",
            "de": "Kavi bereitet den Prompt vor. Deine Dokumente bleiben zwischen dir und dem gewählten Dienst.",
            "es": "Kavi prepara el prompt. Tus documentos quedan entre tú y el servicio que elijas."
        ],
        "ai.instructions.title": [
            "fr": "Avant d’ouvrir %@",
            "en": "Before you open %@",
            "de": "Bevor du %@ öffnest",
            "es": "Antes de abrir %@"
        ],
        "ai.instructions.body": [
            "fr": "Si le prompt n’apparaît pas déjà dans %@, colle-le. Ajoute ensuite tes notes, images ou documents, puis appuie sur Envoyer.",
            "en": "If the prompt isn’t already filled in within %@, paste it. Then attach your notes, images, or documents and press Send.",
            "de": "Falls der Prompt in %@ noch nicht eingefügt ist, füge ihn ein. Hänge dann deine Notizen, Bilder oder Dokumente an und tippe auf Senden.",
            "es": "Si el prompt aún no aparece en %@, pégalo. Después adjunta tus apuntes, imágenes o documentos y pulsa Enviar."
        ],
        "ai.open": [
            "fr": "Ouvrir %@",
            "en": "Open %@",
            "de": "%@ öffnen",
            "es": "Abrir %@"
        ],
        "ai.open_web": [
            "fr": "Ouvrir %@ sur le web",
            "en": "Open %@ on the web",
            "de": "%@ im Web öffnen",
            "es": "Abrir %@ en la web"
        ],
        "ai.copy_prompt": [
            "fr": "Copier le prompt",
            "en": "Copy prompt",
            "de": "Prompt kopieren",
            "es": "Copiar prompt"
        ],
        "ai.prompt_copied": [
            "fr": "Prompt copié dans le presse-papiers",
            "en": "Prompt copied to the clipboard",
            "de": "Prompt in die Zwischenablage kopiert",
            "es": "Prompt copiado al portapapeles"
        ],
        "ai.return.title": [
            "fr": "De retour de %@ ?",
            "en": "Back from %@?",
            "de": "Zurück von %@?",
            "es": "¿Has vuelto de %@?"
        ],
        "ai.return.body": [
            "fr": "Copie le bloc JSON généré dans %@, puis colle-le ici. Tu pourras vérifier et modifier les cartes avant de créer le deck.",
            "en": "Copy the JSON block generated in %@, then paste it here. You can review and edit the cards before creating the deck.",
            "de": "Kopiere den in %@ erzeugten JSON-Block und füge ihn hier ein. Du kannst die Karten vor dem Erstellen des Decks prüfen und bearbeiten.",
            "es": "Copia el bloque JSON generado en %@ y pégalo aquí. Podrás revisar y editar las tarjetas antes de crear el deck."
        ],
        "ai.return.body.combined": [
            "fr": "Copie le bloc JSON généré dans %@, puis colle-le ici. Tu pourras vérifier les cartes, puis les questions avant de créer le deck.",
            "en": "Copy the JSON block generated in %@, then paste it here. You can review the cards and then the questions before creating the deck.",
            "de": "Kopiere den in %@ erzeugten JSON-Block und füge ihn hier ein. Du kannst zuerst die Karten und dann die Fragen prüfen.",
            "es": "Copia el bloque JSON generado en %@ y pégalo aquí. Podrás revisar las tarjetas y después las preguntas antes de crear el deck."
        ],
        "ai.return.body.tests": [
            "fr": "Copie le bloc JSON de tests généré dans %@, puis colle-le ici. Tu pourras vérifier les questions avant de créer le deck.",
            "en": "Copy the test JSON block generated in %@, then paste it here. You can review the questions before creating the deck.",
            "de": "Kopiere den in %@ erzeugten Test-JSON-Block und füge ihn hier ein. Du kannst die Fragen vor dem Erstellen des Decks prüfen.",
            "es": "Copia el bloque JSON de tests generado en %@ y pégalo aquí. Podrás revisar las preguntas antes de crear el deck."
        ],
        "ai.paste": [
            "fr": "Coller depuis %@",
            "en": "Paste from %@",
            "de": "Aus %@ einfügen",
            "es": "Pegar desde %@"
        ],
        "ai.open_again": [
            "fr": "Rouvrir %@",
            "en": "Open %@ again",
            "de": "%@ erneut öffnen",
            "es": "Volver a abrir %@"
        ],
        "ai.error.app_not_installed_title": [
            "fr": "%@ n’est pas installé",
            "en": "%@ isn’t installed",
            "de": "%@ ist nicht installiert",
            "es": "%@ no está instalado"
        ],
        "ai.error.app_not_installed_body": [
            "fr": "Impossible d’ouvrir l’app %@ sur cet iPhone. Le prompt est toujours dans le presse-papiers. Tu peux utiliser l’option web ci-dessous.",
            "en": "The %@ app couldn’t be opened on this iPhone. The prompt is still in your clipboard. You can use the web option below.",
            "de": "Die %@-App konnte auf diesem iPhone nicht geöffnet werden. Der Prompt ist weiterhin in deiner Zwischenablage. Du kannst unten die Web-Version öffnen.",
            "es": "No se pudo abrir la app %@ en este iPhone. El prompt sigue en el portapapeles. Puedes usar la opción web de abajo."
        ],
        "ai.error.clipboard_title": [
            "fr": "Presse-papiers vide",
            "en": "Clipboard empty",
            "de": "Zwischenablage leer",
            "es": "Portapapeles vacío"
        ],
        "ai.error.clipboard_body": [
            "fr": "Copie d’abord le bloc JSON généré par l’IA, puis réessaie.",
            "en": "Copy the JSON block generated by the AI first, then try again.",
            "de": "Kopiere zuerst den von der KI erzeugten JSON-Block und versuche es erneut.",
            "es": "Copia primero el bloque JSON generado por la IA y vuelve a intentarlo."
        ],
        "ai.error.invalid_title": [
            "fr": "JSON non reconnu",
            "en": "JSON not recognized",
            "de": "JSON nicht erkannt",
            "es": "JSON no reconocido"
        ],
        "ai.error.invalid_body": [
            "fr": "Le contenu collé ne correspond pas au format de flashcards attendu. Recopie le bloc JSON complet depuis l’IA.",
            "en": "The pasted content doesn’t match the expected flashcard format. Copy the complete JSON block from the AI and try again.",
            "de": "Der eingefügte Inhalt entspricht nicht dem erwarteten Flashcard-Format. Kopiere den vollständigen JSON-Block aus der KI und versuche es erneut.",
            "es": "El contenido pegado no coincide con el formato de tarjetas esperado. Copia el bloque JSON completo de la IA y vuelve a intentarlo."
        ],
        "ai.error.combined_invalid_body": [
            "fr": "Le contenu collé ne correspond pas au format attendu pour les cartes et tests. Recopie le bloc JSON complet depuis l’IA.",
            "en": "The pasted content doesn’t match the expected cards and tests format. Copy the complete JSON block from the AI and try again.",
            "de": "Der eingefügte Inhalt entspricht nicht dem erwarteten Karten- und Testformat. Kopiere den vollständigen JSON-Block aus der KI.",
            "es": "El contenido pegado no coincide con el formato esperado de tarjetas y tests. Copia el bloque JSON completo de la IA."
        ],
        "ai.error.tests_invalid_body": [
            "fr": "Le contenu collé ne correspond pas au format de tests attendu. Recopie le bloc JSON complet depuis l’IA.",
            "en": "The pasted content doesn’t match the expected test format. Copy the complete JSON block from the AI and try again.",
            "de": "Der eingefügte Inhalt entspricht nicht dem erwarteten Testformat. Kopiere den vollständigen JSON-Block aus der KI.",
            "es": "El contenido pegado no coincide con el formato de tests esperado. Copia el bloque JSON completo de la IA."
        ],
        "deck.new.save_error.title": [
            "fr": "Impossible de créer le deck",
            "en": "Couldn’t Create Deck",
            "de": "Deck konnte nicht erstellt werden",
            "es": "No se pudo crear el deck"
        ],
        "ai.error.empty_title": [
            "fr": "Aucune carte trouvée",
            "en": "No flashcards found",
            "de": "Keine Flashcards gefunden",
            "es": "No se encontraron tarjetas"
        ],
        "ai.error.empty_body": [
            "fr": "Le JSON est valide mais ne contient aucune flashcard utilisable.",
            "en": "The JSON is valid but contains no usable flashcards.",
            "de": "Das JSON ist gültig, enthält aber keine nutzbaren Flashcards.",
            "es": "El JSON es válido, pero no contiene tarjetas utilizables."
        ]
    ]

    static func text(_ key: String) -> String {
        if let translations = inlineTranslations[key],
           let value = translations[languageCode] ?? translations["en"] {
            return value
        }

        return String(
            localized: String.LocalizationValue(key),
            locale: locale
        )
    }

    static func format(_ key: String, _ arguments: any CVarArg...) -> String {
        String(
            format: text(key),
            locale: locale,
            arguments: arguments
        )
    }

    static func cards(_ count: Int) -> String {
        format("format.cards", Int64(count))
    }

    static func decks(_ count: Int) -> String {
        count > 1
            ? format("format.decks", Int64(count))
            : format("format.deck", Int64(count))
    }

    static func questions(_ count: Int) -> String {
        format("format.questions", Int64(count))
    }
}
