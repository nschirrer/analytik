import Foundation
import AnalytikCore

/// Formatage des nombres pour l'affichage, en français (espace insécable des milliers, virgule décimale).
enum Formatters {
    static let locale = Locale(identifier: "fr_FR")
    static let placeholder = "–"

    static let integer = make { formatter in
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
    }

    static let decimal = make { formatter in
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
    }

    static let percent = make { formatter in
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
    }

    static let signedPercent = make { formatter in
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
    }

    static let signedInteger = make { formatter in
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.positivePrefix = "+"
    }

    static let signedDecimal = make { formatter in
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
    }

    private static func make(_ configure: (NumberFormatter) -> Void) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.usesGroupingSeparator = true
        configure(formatter)
        return formatter
    }

    static func string(_ value: Double?, _ formatter: NumberFormatter) -> String {
        guard let value = value, value.isFinite else { return placeholder }
        return formatter.string(from: NSNumber(value: value)) ?? placeholder
    }

    /// Unités : entier, ou une décimale si la valeur n'est pas entière (LY estimé).
    static func units(_ value: Double?) -> String {
        guard let value = value, value.isFinite else { return placeholder }
        if value == value.rounded() { return string(value, integer) }
        return string(value, decimal)
    }

    static func cell(_ value: Double?, metric: Metric) -> String {
        switch metric {
        case .nbl, .ly: return units(value)
        case .yoy: return string(value, signedPercent)
        case .mix: return string(value, percent)
        }
    }

    /// Écart A − B : en unités pour NBL/LY, en points pour les ratios.
    static func delta(_ value: Double?, metric: Metric) -> String {
        guard let value = value, value.isFinite else { return placeholder }
        if metric.isAdditive {
            return value == value.rounded() ? string(value, signedInteger) : string(value, signedDecimal)
        }
        return string(value * 100, signedDecimal) + " pt"
    }

    static func deltaPercent(_ value: Double?) -> String {
        string(value, signedPercent)
    }
}
