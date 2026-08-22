import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case french
    case english
    case german
    case spanish

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .automatic: "settings.language.automatic"
        case .french: "settings.language.french"
        case .english: "settings.language.english"
        case .german: "settings.language.german"
        case .spanish: "settings.language.spanish"
        }
    }

    var locale: Locale? {
        switch self {
        case .automatic: nil
        case .french: Locale(identifier: "fr")
        case .english: Locale(identifier: "en")
        case .german: Locale(identifier: "de")
        case .spanish: Locale(identifier: "es")
        }
    }
}

enum AppPreferences {
    static let hapticsKey = "settings.hapticsEnabled"
    static let celebrationsKey = "settings.celebrationsEnabled"
    static let searchScopeKey = "settings.searchScopeEnabled"

    static let homeResumeKey = "settings.home.resumeEnabled"
    static let homeRecentKey = "settings.home.recentEnabled"
    static let homePinnedKey = "settings.home.pinnedEnabled"
    static let studyHistoryKey = "settings.study.historyEnabled"

    static let studyDirectionKey = "study.direction"
    static let studyShuffleKey = "study.shuffle"
    static let studyStarredOnlyKey = "study.starredOnly"
    static let languageKey = "settings.language"
    static let accentColorKey = "settings.accentColor"

    static var hapticsEnabled: Bool {
        get { storedBool(forKey: hapticsKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }

    static var celebrationsEnabled: Bool {
        get { storedBool(forKey: celebrationsKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: celebrationsKey) }
    }

    static var searchScopeEnabled: Bool {
        get { storedBool(forKey: searchScopeKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: searchScopeKey) }
    }

    static var homeResumeEnabled: Bool {
        get { storedBool(forKey: homeResumeKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: homeResumeKey) }
    }

    static var homeRecentEnabled: Bool {
        get { storedBool(forKey: homeRecentKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: homeRecentKey) }
    }

    static var homePinnedEnabled: Bool {
        get { storedBool(forKey: homePinnedKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: homePinnedKey) }
    }

    static var studyHistoryEnabled: Bool {
        get { storedBool(forKey: studyHistoryKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: studyHistoryKey) }
    }

    static var studyDirection: StudyDirection {
        get {
            guard let data = UserDefaults.standard.data(forKey: studyDirectionKey),
                  let value = try? JSONDecoder().decode(StudyDirection.self, from: data) else {
                return .termToDefinition
            }
            return value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: studyDirectionKey)
        }
    }

    static var studyShuffle: Bool {
        get { storedBool(forKey: studyShuffleKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: studyShuffleKey) }
    }

    static var studyStarredOnly: Bool {
        get { storedBool(forKey: studyStarredOnlyKey, defaultValue: false) }
        set { UserDefaults.standard.set(newValue, forKey: studyStarredOnlyKey) }
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

    static var accentColor: AppAccent {
        get {
            guard let value = UserDefaults.standard.string(forKey: accentColorKey) else {
                return .mint
            }
            return AppAccent(rawValue: value) ?? .mint
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: accentColorKey) }
    }

    private static func storedBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}
