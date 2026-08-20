import Observation
import Foundation

@MainActor
@Observable
final class AppSettings {
    var language: AppLanguage {
        didSet { AppPreferences.language = language }
    }

    var hapticsEnabled: Bool {
    didSet { AppPreferences.hapticsEnabled = hapticsEnabled }
}

    var celebrationsEnabled: Bool {
        didSet { AppPreferences.celebrationsEnabled = celebrationsEnabled }
    }

    var searchScopeEnabled: Bool {
        didSet { AppPreferences.searchScopeEnabled = searchScopeEnabled }
    }

    init() {
        language = AppPreferences.language
        hapticsEnabled = AppPreferences.hapticsEnabled
        celebrationsEnabled = AppPreferences.celebrationsEnabled
        searchScopeEnabled = AppPreferences.searchScopeEnabled
    }

    var locale: Locale? { language.locale }
}
