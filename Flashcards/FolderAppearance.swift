import Foundation
import SwiftUI
import UIKit

enum FolderAppearance {
    static let defaultIcon = "folder.fill"
    static let defaultColorHex = "5856D6"

    static let icons: [String] = [
        "folder.fill",
        "book.closed.fill",
        "graduationcap.fill",
        "brain.head.profile.fill",
        "desktopcomputer",
        "apple.terminal.fill",
        "curlybraces",
        "character.book.closed.fill",
        "globe.europe.africa.fill",
        "map.fill",
        "function",
        "sum",
        "plus.forwardslash.minus",
        "calculator.fill",
        "atom",
        "flask.fill",
        "testtube.2",
        "building.columns.fill",
        "chart.line.uptrend.xyaxis",
        "banknote.fill",
        "leaf.fill",
        "dna",
        "text.book.closed.fill",
        "quote.opening",
        "character.bubble.fill",
        "paintpalette.fill",
        "paintbrush.fill",
        "music.note",
        "waveform",
        "heart.fill"
    ].filter { UIImage(systemName: $0) != nil }

    static let presetColors = [
        "5856D6",
        "007AFF",
        "00A8A8",
        "34C759",
        "FF9500",
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
