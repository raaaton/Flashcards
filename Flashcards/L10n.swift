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
