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

    init() {
        language = AppPreferences.language
        hapticsEnabled = AppPreferences.hapticsEnabled
        celebrationsEnabled = AppPreferences.celebrationsEnabled
    }

    var locale: Locale? { language.locale }
}
