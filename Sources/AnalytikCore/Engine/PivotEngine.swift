import Foundation

/// Ce que représentent les lignes du tableau croisé.
public enum SeriesDimension: String, CaseIterable, Codable, Hashable, Sendable {
    /// Les membres de la dimension du fichier (sous-canaux, produits…).
    case member
    case product
    case store
    case channel
    case country
    case report

    public var frenchName: String {
        switch self {
        case .member: return "Lignes du fichier"
        case .product: return "Produit"
        case .store: return "Magasin"
        case .channel: return "Canal"
        case .country: return "Pays"
        case .report: return "Fichier"
        }
    }
}

public struct PivotQuery: Hashable, Sendable {
    public var metric: Metric
    public var series: SeriesDimension
    public var granularity: Granularity
    /// Rapports inclus (nil = tous).
    public var reportIDs: Set<UUID>?
    /// Périodes affichées (nil = toutes celles de la granularité).
    public var periodIDs: Set<String>?
    /// Lignes affichées (nil = toutes).
    public var seriesKeys: Set<String>?
    public var includeTotalMember: Bool

    public init(
        metric: Metric = .nbl,
        series: SeriesDimension = .member,
        granularity: Granularity = .week,
        reportIDs: Set<UUID>? = nil,
        periodIDs: Set<String>? = nil,
        seriesKeys: Set<String>? = nil,
        includeTotalMember: Bool = true
    ) {
        self.metric = metric
        self.series = series
        self.granularity = granularity
        self.reportIDs = reportIDs
        self.periodIDs = periodIDs
        self.seriesKeys = seriesKeys
        self.includeTotalMember = includeTotalMember
    }
}

public struct PivotRow: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    /// Valeur par identifiant de période (absente ⇒ non disponible).
    public var values: [String: Double]
    public var total: Double?
    public var isTotal: Bool

    public init(id: String, label: String, values: [String: Double], total: Double?, isTotal: Bool) {
        self.id = id
        self.label = label
        self.values = values
        self.total = total
        self.isTotal = isTotal
    }

    public func value(for period: Period) -> Double? {
        values[period.id]
    }
}

public struct PivotTable: Hashable, Sendable {
    public var metric: Metric
    public var seriesTitle: String
    public var columns: [Period]
    public var rows: [PivotRow]

    public init(metric: Metric, seriesTitle: String, columns: [Period], rows: [PivotRow]) {
        self.metric = metric
        self.seriesTitle = seriesTitle
        self.columns = columns
        self.rows = rows
    }

    public static let empty = PivotTable(metric: .nbl, seriesTitle: "", columns: [], rows: [])

    public var isEmpty: Bool {
        rows.isEmpty || columns.isEmpty
    }

    public func row(id: String) -> PivotRow? {
        rows.first { $0.id == id }
    }
}

/// Une ligne possible du tableau (pour les filtres).
public struct SeriesOption: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var isTotal: Bool

    public init(id: String, label: String, isTotal: Bool) {
        self.id = id
        self.label = label
        self.isTotal = isTotal
    }
}

public enum PivotEngine {
    // MARK: Sélections disponibles

    public static func selectedReports(_ reports: [Report], query: PivotQuery) -> [Report] {
        guard let ids = query.reportIDs else { return reports }
        return reports.filter { ids.contains($0.id) }
    }

    /// Union triée des périodes d'une granularité sur les rapports.
    public static func availablePeriods(reports: [Report], granularity: Granularity) -> [Period] {
        var seen = Set<Period>()
        for report in reports {
            for period in report.periods(of: granularity) {
                seen.insert(period)
            }
        }
        return seen.sorted()
    }

    /// Lignes possibles, dans l'ordre de première apparition.
    public static func availableSeries(reports: [Report], series: SeriesDimension, includeTotalMember: Bool) -> [SeriesOption] {
        var options: [SeriesOption] = []
        var seen = Set<String>()
        for report in reports {
            switch series {
            case .member:
                for member in report.members {
                    let isTotal = Report.isTotalMember(member)
                    if isTotal && !includeTotalMember { continue }
                    if seen.insert(member).inserted {
                        options.append(SeriesOption(id: member, label: member, isTotal: isTotal))
                    }
                }
            default:
                let key = attributeKey(report, series: series)
                if seen.insert(key).inserted {
                    options.append(SeriesOption(id: key, label: attributeLabel(report, series: series, reports: reports), isTotal: false))
                }
            }
        }
        return options
    }

    /// Titre de la colonne des lignes : la dimension du fichier ou le nom de l'attribut.
    public static func seriesTitle(reports: [Report], series: SeriesDimension) -> String {
        switch series {
        case .member:
            let dimensions = Array(Set(reports.map { $0.dimension }))
            return dimensions.count == 1 ? dimensions[0] : "Membre"
        default:
            return series.frenchName
        }
    }

    /// Vrai si les rapports sélectionnés n'ont pas tous la même dimension (les membres ne sont pas comparables).
    public static func hasMixedDimensions(_ reports: [Report]) -> Bool {
        Set(reports.map { $0.dimension }).count > 1
    }

    // MARK: Pivot

    public static func pivot(reports allReports: [Report], query: PivotQuery) -> PivotTable {
        let reports = selectedReports(allReports, query: query)
        var columns = availablePeriods(reports: reports, granularity: query.granularity)
        if let ids = query.periodIDs {
            columns = columns.filter { ids.contains($0.id) }
        }
        let options = availableSeries(reports: reports, series: query.series, includeTotalMember: query.includeTotalMember)

        // sums[série][période] et périmètre (NBL total) par période.
        var sums: [String: [String: Sums]] = [:]
        var scope: [String: Sums] = [:]
        for report in reports {
            for period in columns {
                for contribution in contributions(of: report, series: query.series, period: period, includeTotalMember: query.includeTotalMember) {
                    sums[contribution.key, default: [:]][period.id, default: Sums()].add(nbl: contribution.nbl, ly: contribution.ly)
                }
                let total = reportTotal(report, period: period)
                scope[period.id, default: Sums()].add(nbl: total.nbl, ly: total.ly)
            }
        }

        var rows: [PivotRow] = []
        for option in options {
            if let keys = query.seriesKeys, !keys.contains(option.id) { continue }
            var values: [String: Double] = [:]
            var rowSums = Sums()
            var scopeSums = Sums()
            for period in columns {
                let cell = sums[option.id]?[period.id] ?? Sums()
                let periodScope = scope[period.id]?.nbl
                if let value = metricValue(cell, metric: query.metric, scope: periodScope) {
                    values[period.id] = value
                }
                rowSums.add(nbl: cell.nbl, ly: cell.ly)
                scopeSums.add(nbl: periodScope, ly: nil)
            }
            let total = metricValue(rowSums, metric: query.metric, scope: scopeSums.nbl)
            rows.append(PivotRow(id: option.id, label: option.label, values: values, total: total, isTotal: option.isTotal))
        }

        return PivotTable(
            metric: query.metric,
            seriesTitle: seriesTitle(reports: reports, series: query.series),
            columns: columns,
            rows: rows
        )
    }

    // MARK: Internes

    struct Sums: Hashable {
        var nbl: Double?
        var ly: Double?

        mutating func add(nbl n: Double?, ly l: Double?) {
            if let n = n { nbl = (nbl ?? 0) + n }
            if let l = l { ly = (ly ?? 0) + l }
        }
    }

    struct Contribution {
        var key: String
        var nbl: Double?
        var ly: Double?
    }

    static func metricValue(_ sums: Sums, metric: Metric, scope: Double?) -> Double? {
        switch metric {
        case .nbl:
            return sums.nbl
        case .ly:
            return sums.ly
        case .yoy:
            guard let n = sums.nbl, let l = sums.ly, l != 0 else { return nil }
            return n / l - 1
        case .mix:
            guard let n = sums.nbl, let s = scope, s != 0 else { return nil }
            return n / s
        }
    }

    /// NBL et LY « total » d'un rapport pour une période : le membre TOTAL s'il existe, sinon la somme des membres.
    static func reportTotal(_ report: Report, period: Period) -> Sums {
        var sums = Sums()
        if let total = report.totalMember {
            sums.add(nbl: report.value(member: total, metric: .nbl, period: period),
                     ly: report.value(member: total, metric: .ly, period: period))
        } else {
            for member in report.leafMembers {
                sums.add(nbl: report.value(member: member, metric: .nbl, period: period),
                         ly: report.value(member: member, metric: .ly, period: period))
            }
        }
        return sums
    }

    static func contributions(of report: Report, series: SeriesDimension, period: Period, includeTotalMember: Bool) -> [Contribution] {
        switch series {
        case .member:
            var result: [Contribution] = []
            for member in report.members {
                if !includeTotalMember && Report.isTotalMember(member) { continue }
                result.append(Contribution(
                    key: member,
                    nbl: report.value(member: member, metric: .nbl, period: period),
                    ly: report.value(member: member, metric: .ly, period: period)
                ))
            }
            return result
        default:
            let total = reportTotal(report, period: period)
            return [Contribution(key: attributeKey(report, series: series), nbl: total.nbl, ly: total.ly)]
        }
    }

    static let missingLabel = "(non renseigné)"

    static func attributeKey(_ report: Report, series: SeriesDimension) -> String {
        let raw: String
        switch series {
        case .member: raw = ""
        case .product: raw = report.product
        case .store: raw = report.store
        case .channel: raw = report.channel
        case .country: raw = report.country
        case .report: raw = report.fileName + "#" + report.sheetName
        }
        return raw.isEmpty ? missingLabel : raw
    }

    static func attributeLabel(_ report: Report, series: SeriesDimension, reports: [Report]) -> String {
        switch series {
        case .report:
            let sameName = reports.filter { $0.fileName == report.fileName }.count
            return sameName > 1 ? "\(report.fileName) (\(report.sheetName))" : report.fileName
        default:
            return attributeKey(report, series: series)
        }
    }
}
