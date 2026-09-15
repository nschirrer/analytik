import Foundation

/// Reconnaît les étiquettes de périodes d'un en-tête GOLD.
///
/// Le parseur est à état : une semaine nue (« W2 ») hérite de l'année fiscale et du trimestre
/// de la dernière étiquette explicite (« FY26Q3_W1 »).
public struct PeriodParser {
    private var contextFiscalYear: Int?
    private var contextQuarter: Int?

    public init() {}

    /// Analyse tout un en-tête, dans l'ordre des colonnes.
    public static func parseHeader(_ labels: [String]) -> [Period] {
        var parser = PeriodParser()
        return labels.enumerated().map { parser.parse($0.element, columnIndex: $0.offset) }
    }

    public mutating func parse(_ raw: String, columnIndex: Int) -> Period {
        let label = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let groups = Self.match(Self.fullWeek, label),
           let fy = Self.fiscalYear(groups[1]), let q = Int(groups[2]), let w = Int(groups[3]) {
            contextFiscalYear = fy
            contextQuarter = q
            return .week(fiscalYear: fy, quarter: q, week: w)
        }
        if let groups = Self.match(Self.bareWeek, label), let w = Int(groups[1]) {
            if let fy = contextFiscalYear, let q = contextQuarter {
                return .week(fiscalYear: fy, quarter: q, week: w)
            }
            return .opaque(label: label, order: columnIndex)
        }
        if let groups = Self.match(Self.quarterWithYear, label),
           let fy = Self.fiscalYear(groups[1]), let q = Int(groups[2]) {
            return .quarter(fiscalYear: fy, quarter: q)
        }
        if let groups = Self.match(Self.bareQuarter, label), let q = Int(groups[1]) {
            if let fy = contextFiscalYear {
                return .quarter(fiscalYear: fy, quarter: q)
            }
            return .opaque(label: label, order: columnIndex)
        }
        return .opaque(label: label, order: columnIndex)
    }

    // MARK: Expressions régulières

    private static let fullWeek = regex(#"^FY\s*(\d{2,4})\s*Q([1-4])[\s_\-]*W\s*(\d{1,2})$"#)
    private static let bareWeek = regex(#"^W\s*(\d{1,2})$"#)
    private static let quarterWithYear = regex(#"^(?:FY)?\s*(\d{2,4})\s*['’]?\s*Q([1-4])$"#)
    private static let bareQuarter = regex(#"^Q([1-4])$"#)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Les motifs sont constants et valides : un échec ici serait une erreur de programmation.
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    /// Renvoie les groupes capturés (index 0 = correspondance entière) ou nil.
    private static func match(_ regex: NSRegularExpression, _ text: String) -> [String]? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<result.numberOfRanges {
            if let r = Range(result.range(at: i), in: text) {
                groups.append(String(text[r]))
            } else {
                groups.append("")
            }
        }
        return groups
    }

    private static func fiscalYear(_ digits: String) -> Int? {
        guard let value = Int(digits) else { return nil }
        return value < 100 ? 2000 + value : value
    }
}
