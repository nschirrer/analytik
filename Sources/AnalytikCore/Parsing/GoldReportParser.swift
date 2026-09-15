import Foundation

public enum GoldParseError: Error, LocalizedError, Equatable {
    case noHeaderRow(sheet: String)
    case noDataRows(sheet: String)
    case noUsableSheet(file: String)

    public var errorDescription: String? {
        switch self {
        case let .noHeaderRow(sheet):
            return "Feuille « \(sheet) » : aucune ligne d'en-tête avec des périodes n'a été trouvée."
        case let .noDataRows(sheet):
            return "Feuille « \(sheet) » : aucune ligne de données sous l'en-tête."
        case let .noUsableSheet(file):
            return "« \(file) » ne contient aucune feuille au format des exports GOLD."
        }
    }
}

/// Transforme une grille de feuille GOLD en `Report`.
///
/// Mise en page attendue :
/// 1. un bloc de métadonnées (colonne A = libellé, valeur dans les colonnes suivantes) ;
/// 2. une ligne d'en-tête : A = nom de la dimension, B vide, C… = périodes ;
/// 3. des lignes de données : A = membre (vide ⇒ membre précédent), B = métrique, C… = valeurs.
public enum GoldReportParser {
    /// Lit le classeur et renvoie le rapport de la première feuille exploitable.
    public static func parse(fileURL: URL) throws -> Report {
        let grids = try XLSXGridReader.readSheets(atPath: fileURL.path)
        var firstError: Error?
        for grid in grids {
            do {
                return try parse(grid: grid, fileName: fileURL.lastPathComponent, filePath: fileURL.path)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if grids.count == 1, let error = firstError { throw error }
        throw GoldParseError.noUsableSheet(file: fileURL.lastPathComponent)
    }

    /// Lit toutes les feuilles exploitables d'un classeur.
    public static func parseAllSheets(fileURL: URL) throws -> [Report] {
        let grids = try XLSXGridReader.readSheets(atPath: fileURL.path)
        let reports = grids.compactMap { grid -> Report? in
            try? parse(grid: grid, fileName: fileURL.lastPathComponent, filePath: fileURL.path)
        }
        if reports.isEmpty { throw GoldParseError.noUsableSheet(file: fileURL.lastPathComponent) }
        return reports
    }

    public static func parse(grid: SheetGrid, fileName: String, filePath: String) throws -> Report {
        let rows = grid.rows.map { $0.map(clean) }

        guard let headerIndex = findHeaderRow(rows) else {
            throw GoldParseError.noHeaderRow(sheet: grid.name)
        }
        let header = rows[headerIndex]

        // Métadonnées : lignes au-dessus de l'en-tête, libellé en A, valeur à droite.
        var metadata: [String: String] = [:]
        var metadataOrder: [String] = []
        for r in 0..<headerIndex {
            let row = rows[r]
            guard let key = cell(row, 0) else { continue }
            let value = row.dropFirst(1).compactMap { $0 }.joined(separator: " ")
            guard !value.isEmpty else { continue }
            if metadata[key] == nil { metadataOrder.append(key) }
            metadata[key] = value
        }

        let dimension = cell(header, 0) ?? "Dimension"

        // Périodes : cellules non vides à partir de la colonne C.
        var periodColumns: [(column: Int, label: String)] = []
        for c in stride(from: 2, to: header.count, by: 1) {
            if let label = cell(header, c) { periodColumns.append((c, label)) }
        }
        let periods = PeriodParser.parseHeader(periodColumns.map { $0.label })
        let columnsWithPeriods = zip(periodColumns.map { $0.column }, periods).map { ($0, $1) }

        // Données.
        var facts: [Fact] = []
        var members: [String] = []
        var metrics: [String] = []
        var currentMember: String?
        var sawData = false
        let defaultMetric = metadata["Measures"] ?? "NBL"

        for r in (headerIndex + 1)..<rows.count {
            let row = rows[r]
            let isBlank = row.allSatisfy { $0 == nil }
            if isBlank {
                if sawData { break }
                continue
            }
            if let member = cell(row, 0) { currentMember = member }
            guard let member = currentMember else { continue }
            let hasNumbers = columnsWithPeriods.contains { parseNumber(cell(row, $0.0)) != nil }
            guard let metric = cell(row, 1) ?? (hasNumbers ? defaultMetric : nil) else { continue }

            sawData = true
            if !members.contains(member) { members.append(member) }
            if !metrics.contains(metric) { metrics.append(metric) }
            for (column, period) in columnsWithPeriods {
                facts.append(Fact(member: member, metric: metric, period: period, value: parseNumber(cell(row, column))))
            }
        }

        guard sawData else { throw GoldParseError.noDataRows(sheet: grid.name) }

        return Report(
            fileName: fileName,
            filePath: filePath,
            sheetName: grid.name,
            metadata: metadata,
            metadataOrder: metadataOrder,
            dimension: dimension,
            periods: periods,
            members: members,
            metrics: metrics,
            facts: facts
        )
    }

    // MARK: Helpers

    /// L'en-tête est la première ligne ayant au moins trois cellules non vides à partir de la colonne C,
    /// suivie (dans les trois lignes suivantes) d'au moins une valeur numérique.
    static func findHeaderRow(_ rows: [[String?]]) -> Int? {
        for (index, row) in rows.enumerated() {
            let filled = row.dropFirst(2).compactMap { $0 }.count
            guard filled >= 3 else { continue }
            let lookahead = rows[(index + 1)..<min(rows.count, index + 4)]
            let hasNumbers = lookahead.contains { next in
                next.dropFirst(2).contains { parseNumber($0) != nil }
            }
            if hasNumbers { return index }
        }
        return nil
    }

    static func cell(_ row: [String?], _ column: Int) -> String? {
        guard column >= 0, column < row.count else { return nil }
        return row[column]
    }

    /// Trim ; les cellules vides ou ne contenant que des espaces deviennent nil.
    static func clean(_ text: String?) -> String? {
        guard let text = text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Nombre d'une cellule : « 448 », « 0.47 », « -0.5 », « 12 % », « 1,5 » ; « - » et « n/a » ⇒ nil.
    public static func parseNumber(_ text: String?) -> Double? {
        guard let raw = text else { return nil }
        var t = raw
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !t.isEmpty else { return nil }
        let placeholders: Set<String> = ["-", "–", "—", "n/a", "#n/a", "na", "nd", "#div/0!", "#ref!", "#value!"]
        if placeholders.contains(t.lowercased()) { return nil }
        var isPercent = false
        if t.hasSuffix("%") {
            isPercent = true
            t.removeLast()
        }
        if let d = Double(t) { return isPercent ? d / 100 : d }
        let withDot = t.replacingOccurrences(of: ",", with: ".")
        if let d = Double(withDot) { return isPercent ? d / 100 : d }
        return nil
    }
}
