import Foundation

public struct ComparisonRow: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var a: Double?
    public var b: Double?
    /// `a − b`
    public var delta: Double?
    /// `(a − b) / |b|`, seulement pour les métriques additives.
    public var deltaPct: Double?
    public var isTotal: Bool

    public init(id: String, label: String, a: Double?, b: Double?, delta: Double?, deltaPct: Double?, isTotal: Bool) {
        self.id = id
        self.label = label
        self.a = a
        self.b = b
        self.delta = delta
        self.deltaPct = deltaPct
        self.isTotal = isTotal
    }
}

public struct ComparisonTable: Hashable, Sendable {
    public var metric: Metric
    public var rowsTitle: String
    public var titleA: String
    public var titleB: String
    public var rows: [ComparisonRow]

    public init(metric: Metric, rowsTitle: String, titleA: String, titleB: String, rows: [ComparisonRow]) {
        self.metric = metric
        self.rowsTitle = rowsTitle
        self.titleA = titleA
        self.titleB = titleB
        self.rows = rows
    }

    public static let empty = ComparisonTable(metric: .nbl, rowsTitle: "", titleA: "", titleB: "", rows: [])

    public var isEmpty: Bool { rows.isEmpty }

    /// Vrai si la colonne « Δ % » a un sens (métrique additive).
    public var showsDeltaPercent: Bool { metric.isAdditive }
}

public enum ComparisonEngine {
    /// Compare deux périodes : une ligne par série.
    public static func comparePeriods(_ table: PivotTable, a: String, b: String) -> ComparisonTable {
        guard let periodA = table.columns.first(where: { $0.id == a }),
              let periodB = table.columns.first(where: { $0.id == b }) else { return .empty }
        let rows = table.rows.map { row in
            makeRow(id: row.id, label: row.label, a: row.values[periodA.id], b: row.values[periodB.id], metric: table.metric, isTotal: row.isTotal)
        }
        return ComparisonTable(metric: table.metric, rowsTitle: table.seriesTitle, titleA: periodA.label, titleB: periodB.label, rows: rows)
    }

    /// Compare deux séries : une ligne par période.
    public static func compareSeries(_ table: PivotTable, a: String, b: String) -> ComparisonTable {
        guard let rowA = table.row(id: a), let rowB = table.row(id: b) else { return .empty }
        let rows = table.columns.map { period in
            makeRow(id: period.id, label: period.label, a: rowA.values[period.id], b: rowB.values[period.id], metric: table.metric, isTotal: false)
        }
        return ComparisonTable(metric: table.metric, rowsTitle: "Période", titleA: rowA.label, titleB: rowB.label, rows: rows)
    }

    /// Année en cours (NBL) contre année précédente (LY), cumulées sur les périodes de la requête : une ligne par série.
    public static func currentVsLastYear(reports: [Report], query: PivotQuery) -> ComparisonTable {
        var current = query
        current.metric = .nbl
        var previous = query
        previous.metric = .ly
        let cy = PivotEngine.pivot(reports: reports, query: current)
        let ly = PivotEngine.pivot(reports: reports, query: previous)
        let rows = cy.rows.map { row in
            makeRow(id: row.id, label: row.label, a: row.total, b: ly.row(id: row.id)?.total, metric: .nbl, isTotal: row.isTotal)
        }
        return ComparisonTable(metric: .nbl, rowsTitle: cy.seriesTitle, titleA: "Année en cours (NBL)", titleB: "Année précédente (LY)", rows: rows)
    }

    static func makeRow(id: String, label: String, a: Double?, b: Double?, metric: Metric, isTotal: Bool) -> ComparisonRow {
        var delta: Double?
        var deltaPct: Double?
        if let a = a, let b = b {
            delta = a - b
            if metric.isAdditive, b != 0 {
                deltaPct = (a - b) / abs(b)
            }
        }
        return ComparisonRow(id: id, label: label, a: a, b: b, delta: delta, deltaPct: deltaPct, isTotal: isTotal)
    }
}
