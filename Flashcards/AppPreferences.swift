import Foundation

@MainActor
enum AppPreferences {
    static let hapticsKey = "settings.hapticsEnabled"
    static let celebrationsKey = "settings.celebrationsEnabled"

    static var hapticsEnabled: Bool {
        get { storedBool(forKey: hapticsKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }

    static var celebrationsEnabled: Bool {
        get { storedBool(forKey: celebrationsKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: celebrationsKey) }
    }

    private static func storedBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}
