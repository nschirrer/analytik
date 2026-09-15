import Foundation

/// Une valeur d'un export : (membre de la dimension, métrique, période) → valeur.
public struct Fact: Hashable, Sendable {
    public var member: String
    public var metric: String
    public var period: Period
    public var value: Double?

    public init(member: String, metric: String, period: Period, value: Double?) {
        self.member = member
        self.metric = metric
        self.period = period
        self.value = value
    }
}

/// Clé de recherche d'une valeur dans un rapport.
public struct FactKey: Hashable, Sendable {
    public var member: String
    public var metric: String
    public var periodID: String

    public init(member: String, metric: String, periodID: String) {
        self.member = member
        self.metric = metric
        self.periodID = periodID
    }
}

/// Un export GOLD importé (une feuille d'un classeur).
public struct Report: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var fileName: String
    public var filePath: String
    public var sheetName: String
    /// Métadonnées brutes du bloc d'en-tête (« Product » → « iPhone »…).
    public var metadata: [String: String]
    /// Ordre d'apparition des métadonnées dans le fichier.
    public var metadataOrder: [String]
    /// Nom de la dimension en lignes (« Sub-Channel », « Product »…).
    public var dimension: String
    /// Périodes dans l'ordre des colonnes du fichier.
    public var periods: [Period]
    /// Membres de la dimension dans l'ordre du fichier (« TOTAL » en premier s'il existe).
    public var members: [String]
    /// Métriques dans l'ordre du fichier (étiquettes brutes).
    public var metrics: [String]
    public var facts: [Fact]
    /// Index des valeurs non nulles.
    public var values: [FactKey: Double]

    public init(
        id: UUID = UUID(),
        fileName: String,
        filePath: String,
        sheetName: String,
        metadata: [String: String],
        metadataOrder: [String],
        dimension: String,
        periods: [Period],
        members: [String],
        metrics: [String],
        facts: [Fact]
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.sheetName = sheetName
        self.metadata = metadata
        self.metadataOrder = metadataOrder
        self.dimension = dimension
        self.periods = periods
        self.members = members
        self.metrics = metrics
        self.facts = facts
        var index: [FactKey: Double] = [:]
        for fact in facts {
            if let v = fact.value {
                index[FactKey(member: fact.member, metric: fact.metric, periodID: fact.period.id)] = v
            }
        }
        self.values = index
    }

    // MARK: Métadonnées usuelles

    public var product: String { metadataValue(["Product", "Produit"]) }
    public var channel: String { metadataValue(["Channel", "Canal"]) }
    public var store: String { metadataValue(["Store ID - Name", "Store", "Magasin"]) }
    public var country: String { metadataValue(["Country/Region", "Country", "Pays"]) }
    public var type: String { metadataValue(["Type"]) }
    public var measures: String { metadataValue(["Measures", "Measure", "Mesure"]) }

    /// Première métadonnée trouvée parmi les clés candidates (comparaison insensible à la casse).
    public func metadataValue(_ keys: [String]) -> String {
        for key in keys {
            if let exact = metadata[key], !exact.isEmpty { return exact }
            let lowered = key.lowercased()
            if let pair = metadata.first(where: { $0.key.lowercased() == lowered }), !pair.value.isEmpty {
                return pair.value
            }
        }
        return ""
    }

    // MARK: Accès aux valeurs

    public static func isTotalMember(_ member: String) -> Bool {
        member.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "TOTAL"
    }

    /// Le membre « TOTAL » du fichier, s'il existe.
    public var totalMember: String? {
        members.first(where: Report.isTotalMember)
    }

    /// Les membres hors TOTAL.
    public var leafMembers: [String] {
        members.filter { !Report.isTotalMember($0) }
    }

    public func value(member: String, metric: String, period: Period) -> Double? {
        values[FactKey(member: member, metric: metric, periodID: period.id)]
    }

    public func value(member: String, metric: Metric, period: Period) -> Double? {
        guard let raw = rawMetricName(for: metric) else { return nil }
        return value(member: member, metric: raw, period: period)
    }

    /// L'étiquette brute du fichier correspondant à une métrique connue.
    public func rawMetricName(for metric: Metric) -> String? {
        metrics.first { Metric.normalize($0) == metric }
    }

    /// Les métriques connues présentes dans le fichier.
    public var knownMetrics: [Metric] {
        metrics.compactMap(Metric.normalize)
    }

    public func periods(of granularity: Granularity) -> [Period] {
        periods.filter { $0.granularity == granularity }
    }

    /// LY du fichier, sinon estimé à partir de NBL et y/y (`LY = NBL / (1 + y/y)`).
    ///
    /// Les exports GOLD ne fournissent LY que pour la ligne TOTAL ; pour les autres membres
    /// l'estimation permet de recalculer y/y sur des sommes (semaines, rapports).
    public func lastYear(member: String, period: Period) -> (value: Double?, isDerived: Bool) {
        if let ly = value(member: member, metric: .ly, period: period) {
            return (ly, false)
        }
        guard let nbl = value(member: member, metric: .nbl, period: period),
              let yoy = value(member: member, metric: .yoy, period: period),
              yoy > -1 else { return (nil, false) }
        return (nbl / (1 + yoy), true)
    }

    public static func == (lhs: Report, rhs: Report) -> Bool {
        lhs.id == rhs.id && lhs.filePath == rhs.filePath && lhs.sheetName == rhs.sheetName
    }
}
