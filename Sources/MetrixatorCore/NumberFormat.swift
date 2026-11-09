import Foundation

/// Mise en forme et lecture des nombres (indépendante de `NumberFormatter` pour un rendu identique partout).
public enum NumberFormat {
    static var decimalSeparator: String { L10n.current == .en ? "." : "," }
    /// Espace fine insécable en français, virgule en anglais.
    static var groupingSeparator: String { L10n.current == .en ? "," : "\u{202F}" }

    /// Nombre avec séparateurs de milliers et au plus `maxDecimals` décimales (zéros finaux retirés).
    public static func plain(_ value: Double, maxDecimals: Int) -> String {
        guard value.isFinite else { return "—" }
        let factor = pow(10.0, Double(maxDecimals))
        var rounded = (abs(value) * factor).rounded() / factor
        if rounded == 0 { rounded = 0 }
        let negative = value < 0 && rounded != 0
        let intPart = Int(rounded.rounded(.towardZero))
        var frac = Int(((rounded - Double(intPart)) * factor).rounded())
        var intValue = intPart
        if frac >= Int(factor) { intValue += 1; frac = 0 }

        var digits = String(intValue)
        var groups: [String] = []
        while digits.count > 3 {
            groups.insert(String(digits.suffix(3)), at: 0)
            digits = String(digits.dropLast(3))
        }
        groups.insert(digits, at: 0)
        var s = groups.joined(separator: groupingSeparator)

        if maxDecimals > 0 && frac > 0 {
            var f = String(frac)
            f = String(repeating: "0", count: maxDecimals - f.count) + f
            while f.hasSuffix("0") { f.removeLast() }
            s += decimalSeparator + f
        }
        return (negative ? "−" : "") + s
    }

    /// Nombre de décimales adapté à l'ordre de grandeur.
    static func autoDecimals(_ value: Double) -> Int {
        let a = abs(value)
        if a >= 100 { return 0 }
        if a >= 10 { return 1 }
        return 2
    }

    /// Valeur principale d'une tuile : compacte au-delà de 100 000 (« 112,4 k », « 1,25 M »).
    public static func value(_ value: Double?, compact: Bool = true) -> String {
        guard let value, value.isFinite else { return "—" }
        let a = abs(value)
        if compact && a >= 1_000_000_000 { return plain(value / 1_000_000_000, maxDecimals: 2) + "\u{00A0}" + L10n.tr("Md", "B") }
        if compact && a >= 1_000_000 { return plain(value / 1_000_000, maxDecimals: 2) + "\u{00A0}M" }
        if compact && a >= 100_000 { return plain(value / 1_000, maxDecimals: 1) + "\u{00A0}k" }
        return plain(value, maxDecimals: autoDecimals(value))
    }

    /// Valeur complète avec son unité (« 12 345 € », « 32,5 % »).
    public static func valueWithUnit(_ v: Double?, unit: String, compact: Bool = false) -> String {
        let s = value(v, compact: compact)
        guard v != nil, !unit.isEmpty else { return s }
        if L10n.current == .en && (unit == "€" || unit == "$" || unit == "£") { return unit + s }
        if L10n.current == .en && unit == "%" { return s + "%" }
        return s + "\u{00A0}" + unit
    }

    /// Progression signée : « +4,2 % » ou « −1,3 pt ».
    public static func change(_ v: Double?, inPoints: Bool) -> String {
        guard let v, v.isFinite else { return "—" }
        let decimals = abs(v) >= 100 ? 0 : 1
        let body = plain(abs(v), maxDecimals: decimals)
        let factor = pow(10.0, Double(decimals))
        let rounded = (abs(v) * factor).rounded() / factor
        let sign = rounded == 0 ? "" : (v > 0 ? "+" : "−")
        if inPoints {
            let unit = L10n.current == .en ? (abs(v) == 1 ? " pt" : " pts") : "\u{00A0}pt"
            return sign + body + unit
        }
        return sign + body + (L10n.current == .en ? "%" : "\u{00A0}%")
    }

    // MARK: - Lecture

    /// Lit un nombre saisi : « 12 345,6 », « 12,345.6 », « 1 234 € », « +4,5 % », « -3 ».
    /// Renvoie `nil` si la saisie n'est pas un nombre.
    public static func parse(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        // Retire unités et espaces.
        for token in ["€", "$", "£", "%", "pts", "pt", "points"] {
            s = s.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
        }
        s = s.replacingOccurrences(of: "\u{2212}", with: "-") // signe moins typographique
        s = s.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\u{00A0}\u{202F}\u{2009}'"))).joined()
        guard !s.isEmpty else { return nil }

        var sign = 1.0
        if s.hasPrefix("-") { sign = -1; s.removeFirst() } else if s.hasPrefix("+") { s.removeFirst() }
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }) else { return nil }

        let commas = s.filter { $0 == "," }.count
        let dots = s.filter { $0 == "." }.count
        var normalized = s
        if commas > 0 && dots > 0 {
            // Le dernier séparateur est le séparateur décimal.
            let lastComma = s.lastIndex(of: ",")!
            let lastDot = s.lastIndex(of: ".")!
            if lastComma > lastDot {
                normalized = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = s.replacingOccurrences(of: ",", with: "")
            }
            guard normalized.filter({ $0 == "." }).count <= 1 else { return nil }
        } else if commas > 1 {
            guard isGrouped(s, separator: ",") else { return nil }
            normalized = s.replacingOccurrences(of: ",", with: "")
        } else if dots > 1 {
            guard isGrouped(s, separator: ".") else { return nil }
            normalized = s.replacingOccurrences(of: ".", with: "")
        } else if commas == 1 {
            // En anglais, « 12,345 » est un séparateur de milliers ; sinon c'est une virgule décimale.
            if L10n.current == .en && isGrouped(s, separator: ",") {
                normalized = s.replacingOccurrences(of: ",", with: "")
            } else {
                normalized = s.replacingOccurrences(of: ",", with: ".")
            }
        }
        if normalized.hasPrefix(".") { normalized = "0" + normalized }
        guard !normalized.hasSuffix("."), let v = Double(normalized), v.isFinite else { return nil }
        return sign * v
    }

    /// Vrai si `s` est de la forme 1,234,567 (groupes de 3 chiffres).
    static func isGrouped(_ s: String, separator: Character) -> Bool {
        let parts = s.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count >= 2, let first = parts.first, (1...3).contains(first.count) else { return false }
        return parts.dropFirst().allSatisfy { $0.count == 3 }
    }
}
