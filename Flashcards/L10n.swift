import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        String(
            localized: String.LocalizationValue(key),
            locale: AppPreferences.language.locale ?? Locale.autoupdatingCurrent
        )
    }

    static func format(_ key: String, _ arguments: any CVarArg...) -> String {
        String(
            format: text(key),
            locale: AppPreferences.language.locale ?? Locale.autoupdatingCurrent,
            arguments: arguments
        )
    }

    static func cards(_ count: Int) -> String {
        format("format.cards", Int64(count))
    }

    static func decks(_ count: Int) -> String {
        count > 1 ? format("format.decks", Int64(count)) : "\(count) deck"
    }

    static func questions(_ count: Int) -> String {
        format("format.questions", Int64(count))
    }
}
