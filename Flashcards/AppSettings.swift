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

    var homeResumeEnabled: Bool {
        didSet { AppPreferences.homeResumeEnabled = homeResumeEnabled }
    }

    var homeRecentEnabled: Bool {
        didSet { AppPreferences.homeRecentEnabled = homeRecentEnabled }
    }

    var homePinnedEnabled: Bool {
        didSet { AppPreferences.homePinnedEnabled = homePinnedEnabled }
    }

    var studyHistoryEnabled: Bool {
        didSet { AppPreferences.studyHistoryEnabled = studyHistoryEnabled }
    }

    init() {
        language = AppPreferences.language
        hapticsEnabled = AppPreferences.hapticsEnabled
        celebrationsEnabled = AppPreferences.celebrationsEnabled
        searchScopeEnabled = AppPreferences.searchScopeEnabled
        homeResumeEnabled = AppPreferences.homeResumeEnabled
        homeRecentEnabled = AppPreferences.homeRecentEnabled
        homePinnedEnabled = AppPreferences.homePinnedEnabled
        studyHistoryEnabled = AppPreferences.studyHistoryEnabled
    }

    var locale: Locale? { language.locale }
}
