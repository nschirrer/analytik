import Foundation

/// Export d'un tableau croisé en CSV lisible par Excel en français (« ; », virgule décimale, BOM UTF-8).
public enum CSVExporter {
    public static func csv(
        _ table: PivotTable,
        separator: String = ";",
        decimalSeparator: String = ",",
        includeBOM: Bool = true
    ) -> String {
        var lines: [String] = []
        let header = [table.seriesTitle] + table.columns.map { $0.label } + ["Total"]
        lines.append(header.map { escape($0, separator: separator) }.joined(separator: separator))
        for row in table.rows {
            var fields = [escape(row.label, separator: separator)]
            for period in table.columns {
                fields.append(format(row.values[period.id], decimalSeparator: decimalSeparator))
            }
            fields.append(format(row.total, decimalSeparator: decimalSeparator))
            lines.append(fields.joined(separator: separator))
        }
        let body = lines.joined(separator: "\r\n") + "\r\n"
        return (includeBOM ? "\u{FEFF}" : "") + body
    }

    static func format(_ value: Double?, decimalSeparator: String) -> String {
        guard let value = value else { return "" }
        return NumberText.plain(value).replacingOccurrences(of: ".", with: decimalSeparator)
    }

    static func escape(_ field: String, separator: String) -> String {
        let needsQuotes = field.contains(separator) || field.contains("\"") || field.contains("\n") || field.contains("\r")
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
