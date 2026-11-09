import Foundation

/// Import / export CSV des valeurs hebdomadaires.
///
/// Format (une ligne par résultat et par semaine) :
/// `resultat;semaine;semaine_fiscale;valeur;yoy_saisi;nature;unite;agregation`
/// À l'import, seules les colonnes `resultat`, `semaine` (n'importe quel jour de la semaine, AAAA-MM-JJ)
/// et `valeur` sont obligatoires. Le séparateur `;` ou `,` est détecté automatiquement.
public enum CSV {
    public struct ImportReport: Equatable, Sendable {
        public var addedEntries = 0
        public var createdMetrics = 0
        /// Lignes ignorées car la valeur existait déjà (doublon bloqué).
        public var duplicates: [Int] = []
        /// Lignes en erreur, avec le motif.
        public var errors: [(line: Int, message: String)] = []

        public static func == (a: ImportReport, b: ImportReport) -> Bool {
            a.addedEntries == b.addedEntries && a.createdMetrics == b.createdMetrics && a.duplicates == b.duplicates
                && a.errors.map(\.line) == b.errors.map(\.line)
        }

        public var summary: String {
            var parts = [L10n.tr("\(addedEntries) valeur(s) importée(s)", "\(addedEntries) value(s) imported")]
            if createdMetrics > 0 { parts.append(L10n.tr("\(createdMetrics) résultat(s) créé(s)", "\(createdMetrics) result(s) created")) }
            if !duplicates.isEmpty { parts.append(L10n.tr("\(duplicates.count) doublon(s) ignoré(s)", "\(duplicates.count) duplicate(s) skipped")) }
            if !errors.isEmpty { parts.append(L10n.tr("\(errors.count) ligne(s) en erreur", "\(errors.count) line(s) with errors")) }
            return parts.joined(separator: " · ")
        }
    }

    static let header = ["resultat", "semaine", "semaine_fiscale", "valeur", "yoy_saisi", "nature", "unite", "agregation"]

    // MARK: Export

    public static func export(_ metrics: [Metric], calendar cal: FiscalCalendar) -> String {
        var lines = [header.joined(separator: ";")]
        for m in metrics {
            for e in m.entries {
                let w = cal.week(containing: e.week)
                let fields = [m.name, e.week.iso, "W\(w.index) \(L10n.fiscalYear(w.fiscalYear))",
                              numberString(e.value), e.manualYoY.map(numberString) ?? "",
                              m.kind.rawValue, m.unit, m.aggregation.rawValue]
                lines.append(fields.map(escape).joined(separator: ";"))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Nombres exportés avec un point décimal et sans séparateur de milliers (lisibles partout).
    static func numberString(_ v: Double) -> String {
        if v == v.rounded(), abs(v) < 1e15 { return String(Int(v)) }
        var s = String(format: "%.6f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    static func escape(_ s: String) -> String {
        if s.contains(";") || s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    // MARK: Lecture

    /// Découpe un texte CSV (guillemets RFC 4180) avec le séparateur donné.
    public static func parse(_ text: String, separator: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        if chars.first == "\u{FEFF}" { chars.removeFirst() }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == separator {
                row.append(field); field = ""
            } else if c == "\n" {
                row.append(field); field = ""
                rows.append(row); row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    static func detectSeparator(_ text: String) -> Character {
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        return firstLine.filter { $0 == ";" }.count >= firstLine.filter { $0 == "," }.count ? ";" : ","
    }

    static func column(_ header: [String], _ names: [String]) -> Int? {
        let normalized = header.map { Metric.normalize($0).replacingOccurrences(of: " ", with: "_") }
        for n in names { if let i = normalized.firstIndex(of: n) { return i } }
        return nil
    }

    // MARK: Import

    /// Fusionne le CSV dans la liste de résultats. Ne modifie jamais une valeur existante.
    public static func merge(_ text: String, into metrics: [Metric], calendar cal: FiscalCalendar, today: Day) -> ([Metric], ImportReport) {
        var report = ImportReport()
        var result = metrics
        let sep = detectSeparator(text)
        let rows = parse(text, separator: sep).filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        guard let header = rows.first else {
            report.errors.append((1, L10n.tr("Fichier vide.", "Empty file.")))
            return (result, report)
        }
        guard let cName = column(header, ["resultat", "result", "metric", "nom", "name"]),
              let cWeek = column(header, ["semaine", "week", "week_start", "date"]),
              let cValue = column(header, ["valeur", "value"]) else {
            report.errors.append((1, L10n.tr("Colonnes obligatoires : resultat, semaine, valeur.", "Required columns: resultat, semaine, valeur.")))
            return (result, report)
        }
        let cYoY = column(header, ["yoy_saisi", "yoy", "y/y"])
        let cKind = column(header, ["nature", "kind"])
        let cUnit = column(header, ["unite", "unit"])
        let cAgg = column(header, ["agregation", "aggregation"])

        for (offset, row) in rows.dropFirst().enumerated() {
            let line = offset + 2
            func field(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespaces)
            }
            let name = field(cName)
            guard !Metric.normalize(name).isEmpty else {
                report.errors.append((line, L10n.tr("Nom de résultat manquant.", "Missing result name."))); continue
            }
            guard let day = Day(iso: field(cWeek)) else {
                report.errors.append((line, L10n.tr("Date incorrecte (format attendu AAAA-MM-JJ).", "Invalid date (expected YYYY-MM-DD)."))); continue
            }
            guard let value = NumberFormat.parse(field(cValue)) else {
                report.errors.append((line, MetrixError.invalidValue.message)); continue
            }
            let week = cal.week(containing: day)
            guard week.end < today else {
                report.errors.append((line, MetrixError.incompleteWeek.message)); continue
            }

            var index = result.firstIndex { $0.normalizedName == Metric.normalize(name) }
            if index == nil {
                let kind = ValueKind(rawValue: field(cKind)) ?? .units
                let unit = field(cUnit)
                let colors = MetricColor.allCases
                let m = Metric(name: name, kind: kind, unit: unit.isEmpty ? nil : unit,
                               aggregation: Aggregation(rawValue: field(cAgg)),
                               display: .line, color: colors[result.count % colors.count])
                result.append(m)
                report.createdMetrics += 1
                index = result.count - 1
            }
            let i = index!

            var manual: Double?
            let yoyText = field(cYoY)
            if !yoyText.isEmpty {
                guard let y = NumberFormat.parse(yoyText), result[i].kind.comparesInPoints || y > -100 else {
                    report.errors.append((line, MetrixError.invalidYoY.message)); continue
                }
                manual = y
            }
            if result[i].entry(for: week.start) != nil {
                report.duplicates.append(line); continue
            }
            result[i].entries.append(Entry(week: week.start, value: value, manualYoY: manual))
            result[i].entries.sort { $0.week < $1.week }
            report.addedEntries += 1
        }
        return (result, report)
    }
}
