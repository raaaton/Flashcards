import Foundation
import SwiftUI
import UIKit

enum FolderAppearance {
    static let defaultIcon = "folder.fill"
    static let defaultColorHex = "5856D6"

    static let icons = [
        "folder.fill",
        "book.closed.fill",
        "graduationcap.fill",
        "brain.head.profile.fill",
        "character.book.closed.fill",
        "globe.europe.africa.fill",
        "function",
        "atom",
        "testtube.2",
        "building.columns.fill",
        "music.note",
        "heart.fill"
    ]

    static let presetColors = [
        "5856D6",
        "007AFF",
        "00A8A8",
        "34C759",
        "FF9500",
        "FF3B30",
        "AF52DE",
        "FF2D55"
    ]
}

extension Color {
    init(folderHex hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleanHex.count == 6, let value = UInt64(cleanHex, radix: 16) else {
            self = Color(folderHex: FolderAppearance.defaultColorHex)
            return
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var folderHexString: String {
        let resolved = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return FolderAppearance.defaultColorHex
        }

        return String(
            format: "%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}
