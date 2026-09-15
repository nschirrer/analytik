import Foundation

/// Les métriques connues d'un export GOLD.
///
/// - `nbl` : unités facturées nettes (Net Billings) de l'année en cours
/// - `ly` : même période, année précédente (Last Year)
/// - `yoy` : variation `NBL / LY − 1` (0,47 = +47 %)
/// - `mix` : part du membre dans le TOTAL (`NBL membre / NBL TOTAL`)
public enum Metric: String, CaseIterable, Codable, Hashable, Sendable {
    case nbl = "NBL"
    case ly = "LY"
    case yoy = "y/y"
    case mix = "Mix"

    /// Reconnaît une étiquette de métrique telle qu'écrite dans le fichier.
    public static func normalize(_ raw: String) -> Metric? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "nbl", "units", "unites", "unités", "net billings", "cy":
            return .nbl
        case "ly", "last year", "n-1", "py":
            return .ly
        case "y/y", "yoy", "y-o-y", "growth", "var", "variation":
            return .yoy
        case "mix", "share", "part":
            return .mix
        default:
            return nil
        }
    }

    /// Vrai pour les métriques que l'on peut additionner (unités).
    public var isAdditive: Bool {
        self == .nbl || self == .ly
    }

    /// Vrai pour les ratios, qui doivent être recalculés et jamais sommés.
    public var isRatio: Bool {
        !isAdditive
    }

    public var frenchName: String {
        switch self {
        case .nbl: return "Ventes (NBL)"
        case .ly: return "Année précédente (LY)"
        case .yoy: return "Variation (y/y)"
        case .mix: return "Part (Mix)"
        }
    }
}
