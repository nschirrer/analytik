import AppKit
import SwiftUI

/// Palette catégorielle (ordre fixe, validée pour les daltonismes) avec ses variantes en mode sombre.
enum ChartPalette {
    static let maxSeries = 8

    private static let light: [UInt32] = [0x2A78D6, 0xEB6834, 0x1BAF7A, 0xEDA100, 0xE87BA4, 0x008300, 0x4A3AA7, 0xE34948]
    private static let dark: [UInt32] = [0x3987E5, 0xD95926, 0x199E70, 0xC98500, 0xD55181, 0x008300, 0x9085E9, 0xE66767]

    static let positive = dynamicColor(light: 0x006300, dark: 0x0CA30C)
    static let negative = dynamicColor(light: 0xD03B3B, dark: 0xE66767)

    static func colors(count: Int) -> [Color] {
        let n = max(1, min(count, maxSeries))
        return (0..<n).map { dynamicColor(light: light[$0], dark: dark[$0]) }
    }

    static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
        let dynamic = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return makeColor(hex: isDark ? dark : light)
        }
        return Color(nsColor: dynamic)
    }

    private static func makeColor(hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
