import Observation
import SwiftUI

@MainActor
@Observable
final class AppSettings {
    var language: AppLanguage {
        didSet { AppPreferences.language = language }
    }

    var accentHex: String {
        didSet { AppPreferences.accentHex = accentHex }
    }

    var hapticsEnabled: Bool {
        didSet { AppPreferences.hapticsEnabled = hapticsEnabled }
    }

    var celebrationsEnabled: Bool {
        didSet { AppPreferences.celebrationsEnabled = celebrationsEnabled }
    }

    init() {
        language = AppPreferences.language
        accentHex = AppPreferences.accentHex
        hapticsEnabled = AppPreferences.hapticsEnabled
        celebrationsEnabled = AppPreferences.celebrationsEnabled
    }

    var locale: Locale? { language.locale }
    var accentColor: Color { Color(folderHex: accentHex) }

    func resetAccent() {
        accentHex = AppPreferences.defaultAccentHex
    }
}
