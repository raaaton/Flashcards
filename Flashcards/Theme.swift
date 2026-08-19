import SwiftUI

@MainActor
enum Theme {
    static var accent: Color { Color(folderHex: AppPreferences.accentHex) }
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
}
