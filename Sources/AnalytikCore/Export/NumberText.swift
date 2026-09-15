import Foundation

/// Formatage de nombres pour les fichiers (CSV, prompt) : indépendant de la locale, sans séparateur de milliers.
enum NumberText {
    /// « 448 », « 0.47 », « -0.5 » ; au plus quatre décimales, sans zéros de fin.
    static func plain(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "" }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value))
        }
        var text = String(format: "%.4f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
