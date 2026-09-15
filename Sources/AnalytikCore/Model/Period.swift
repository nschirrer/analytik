import Foundation

/// Granularité d'une période : semaine fiscale ou trimestre fiscal.
public enum Granularity: String, CaseIterable, Codable, Hashable, Sendable {
    case week
    case quarter

    public var frenchName: String {
        switch self {
        case .week: return "Semaines"
        case .quarter: return "Trimestres"
        }
    }
}

/// Une colonne de période d'un export GOLD.
///
/// - `week` : semaine fiscale Apple (`FY26Q3_W1`, `W2`…)
/// - `quarter` : total d'un trimestre fiscal (`26'Q2`, `FY26Q3`)
/// - `opaque` : étiquette non reconnue, ordonnée par sa position de colonne
public enum Period: Hashable, Codable, Sendable {
    case week(fiscalYear: Int, quarter: Int, week: Int)
    case quarter(fiscalYear: Int, quarter: Int)
    case opaque(label: String, order: Int)

    public var granularity: Granularity? {
        switch self {
        case .week: return .week
        case .quarter: return .quarter
        case .opaque: return nil
        }
    }

    public var fiscalYear: Int? {
        switch self {
        case let .week(fy, _, _): return fy
        case let .quarter(fy, _): return fy
        case .opaque: return nil
        }
    }

    public var quarterNumber: Int? {
        switch self {
        case let .week(_, q, _): return q
        case let .quarter(_, q): return q
        case .opaque: return nil
        }
    }

    public var weekNumber: Int? {
        if case let .week(_, _, w) = self { return w }
        return nil
    }

    /// Étiquette complète : « FY26 Q3 W1 », « FY26 Q3 », ou l'étiquette brute.
    public var label: String {
        switch self {
        case let .week(fy, q, w): return "FY\(Period.twoDigits(fy)) Q\(q) W\(w)"
        case let .quarter(fy, q): return "FY\(Period.twoDigits(fy)) Q\(q)"
        case let .opaque(label, _): return label
        }
    }

    /// Étiquette courte pour les colonnes : « W1 », « Q3 FY26 », ou l'étiquette brute.
    public var shortLabel: String {
        switch self {
        case let .week(_, _, w): return "W\(w)"
        case let .quarter(fy, q): return "Q\(q) FY\(Period.twoDigits(fy))"
        case let .opaque(label, _): return label
        }
    }

    static func twoDigits(_ fiscalYear: Int) -> String {
        let yy = fiscalYear % 100
        return yy < 10 ? "0\(yy)" : "\(yy)"
    }

    /// Clé de tri : année fiscale, trimestre, semaines avant le total du trimestre, opaques en dernier.
    var sortKey: (Int, Int, Int, Int) {
        switch self {
        case let .week(fy, q, w): return (fy, q, 0, w)
        case let .quarter(fy, q): return (fy, q, 1, 0)
        case let .opaque(_, order): return (Int.max, Int.max, 2, order)
        }
    }
}

extension Period: Identifiable {
    public var id: String {
        switch self {
        case let .week(fy, q, w):
            let ww = w < 10 ? "0\(w)" : "\(w)"
            return "FY\(fy)Q\(q)W\(ww)"
        case let .quarter(fy, q):
            return "FY\(fy)Q\(q)"
        case let .opaque(label, order):
            return "opaque:\(order):\(label)"
        }
    }
}

extension Period: Comparable {
    public static func < (lhs: Period, rhs: Period) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}
