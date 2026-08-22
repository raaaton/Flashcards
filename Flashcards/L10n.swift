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

    static func text(_ key: String) -> String {
        String(
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
