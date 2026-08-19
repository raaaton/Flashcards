import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case french
    case english

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .automatic: "settings.language.automatic"
        case .french: "settings.language.french"
        case .english: "settings.language.english"
        }
    }

    var locale: Locale? {
        switch self {
        case .automatic: nil
        case .french: Locale(identifier: "fr")
        case .english: Locale(identifier: "en")
        }
    }
}

enum AppPreferences {
    static let hapticsKey = "settings.hapticsEnabled"
    static let celebrationsKey = "settings.celebrationsEnabled"
    static let languageKey = "settings.language"
    static let accentHexKey = "settings.accentHex"
    static let defaultAccentHex = "5856D6"

    static var hapticsEnabled: Bool {
        get { storedBool(forKey: hapticsKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }

    static var celebrationsEnabled: Bool {
        get { storedBool(forKey: celebrationsKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: celebrationsKey) }
    }

    static var language: AppLanguage {
        get {
            guard let value = UserDefaults.standard.string(forKey: languageKey) else {
                return .automatic
            }
            return AppLanguage(rawValue: value) ?? .automatic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: languageKey) }
    }

    static var accentHex: String {
        get { UserDefaults.standard.string(forKey: accentHexKey) ?? defaultAccentHex }
        set { UserDefaults.standard.set(newValue, forKey: accentHexKey) }
    }

    private static func storedBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}
