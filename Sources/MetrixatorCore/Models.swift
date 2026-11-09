import Foundation

/// Nature du chiffre suivi.
public enum ValueKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Nombre d'unités, de clients, de rendez-vous…
    case units
    /// Montant (chiffre d'affaires, panier moyen…).
    case currency
    /// Taux exprimé en % (conversion, attachement…). Les progressions sont en points.
    case percent
    /// Score ou indice sans unité (NPS, satisfaction…). Les progressions sont en points.
    case score

    public var id: String { rawValue }

    /// Les taux et scores se comparent en points, les volumes en pourcentage.
    public var comparesInPoints: Bool { self == .percent || self == .score }

    public var defaultAggregation: Aggregation { self == .percent || self == .score ? .average : .sum }

    public var defaultUnit: String {
        switch self {
        case .units: return L10n.tr("unités", "units")
        case .currency: return "€"
        case .percent: return "%"
        case .score: return ""
        }
    }

    public var label: String {
        switch self {
        case .units: return L10n.tr("Unités", "Units")
        case .currency: return L10n.tr("Montant", "Amount")
        case .percent: return L10n.tr("Pourcentage", "Percentage")
        case .score: return L10n.tr("Score / indice", "Score / index")
        }
    }
}

/// Manière de cumuler plusieurs semaines (QTD, YTD…).
public enum Aggregation: String, Codable, CaseIterable, Identifiable, Sendable {
    case sum
    case average

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sum: return L10n.tr("Somme des semaines", "Sum of weeks")
        case .average: return L10n.tr("Moyenne des semaines", "Average of weeks")
        }
    }
}

/// Format d'affichage d'un résultat sur le tableau de synthèse.
public enum DisplayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Chiffre seul (+ progression Y/Y).
    case number
    /// Chiffre + courbe.
    case line
    /// Chiffre + graphique en barres.
    case bars
    /// Progression Y/Y en grand (pourcentage).
    case yoy
    /// Courbe de l'année en cours superposée à l'année précédente.
    case versusLastYear

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .number: return L10n.tr("Chiffre", "Number")
        case .line: return L10n.tr("Courbe", "Line")
        case .bars: return L10n.tr("Barres", "Bars")
        case .yoy: return L10n.tr("Progression Y/Y", "Y/Y growth")
        case .versusLastYear: return L10n.tr("Comparaison N / N-1", "This year vs last")
        }
    }

    /// Nom de symbole SF Symbols.
    public var symbol: String {
        switch self {
        case .number: return "number"
        case .line: return "chart.xyaxis.line"
        case .bars: return "chart.bar.fill"
        case .yoy: return "percent"
        case .versusLastYear: return "chart.line.uptrend.xyaxis"
        }
    }

    public var hasChart: Bool { self == .line || self == .bars || self == .versusLastYear }
}

/// Palette de couleurs proposée pour différencier les résultats.
public enum MetricColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, purple, pink, red, orange, yellow, green, teal, indigo, graphite

    public var id: String { rawValue }

    /// Composantes RVB (0…1) pour le mode clair.
    public var rgb: (Double, Double, Double) {
        switch self {
        case .blue: return (0.16, 0.47, 0.96)
        case .purple: return (0.63, 0.33, 0.86)
        case .pink: return (0.92, 0.29, 0.56)
        case .red: return (0.91, 0.27, 0.24)
        case .orange: return (0.96, 0.56, 0.13)
        case .yellow: return (0.89, 0.71, 0.0)
        case .green: return (0.2, 0.71, 0.36)
        case .teal: return (0.0, 0.66, 0.72)
        case .indigo: return (0.35, 0.36, 0.86)
        case .graphite: return (0.45, 0.48, 0.53)
        }
    }

    public var label: String {
        switch self {
        case .blue: return L10n.tr("Bleu", "Blue")
        case .purple: return L10n.tr("Violet", "Purple")
        case .pink: return L10n.tr("Rose", "Pink")
        case .red: return L10n.tr("Rouge", "Red")
        case .orange: return L10n.tr("Orange", "Orange")
        case .yellow: return L10n.tr("Jaune", "Yellow")
        case .green: return L10n.tr("Vert", "Green")
        case .teal: return L10n.tr("Turquoise", "Teal")
        case .indigo: return L10n.tr("Indigo", "Indigo")
        case .graphite: return L10n.tr("Graphite", "Graphite")
        }
    }
}

/// Une valeur hebdomadaire saisie pour un résultat.
public struct Entry: Codable, Hashable, Identifiable, Sendable {
    /// Premier jour de la semaine fiscale concernée.
    public var week: Day
    public var value: Double
    /// Progression Y/Y saisie à la main (en % pour les volumes, en points pour les taux/scores).
    /// Utilisée seulement si la même semaine de l'année précédente n'est pas dans l'app.
    public var manualYoY: Double?

    public var id: Day { week }

    public init(week: Day, value: Double, manualYoY: Double? = nil) {
        self.week = week
        self.value = value
        self.manualYoY = manualYoY
    }
}

/// Un résultat (indicateur) suivi.
public struct Metric: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var details: String
    public var kind: ValueKind
    public var unit: String
    public var aggregation: Aggregation
    public var higherIsBetter: Bool
    public var display: DisplayStyle
    public var color: MetricColor
    public var showOnDashboard: Bool
    /// Valeurs hebdomadaires, triées par semaine croissante.
    public var entries: [Entry]

    public init(id: UUID = UUID(), name: String, details: String = "", kind: ValueKind = .units,
                unit: String? = nil, aggregation: Aggregation? = nil, higherIsBetter: Bool = true,
                display: DisplayStyle = .number, color: MetricColor = .blue, showOnDashboard: Bool = true,
                entries: [Entry] = []) {
        self.id = id
        self.name = name
        self.details = details
        self.kind = kind
        self.unit = unit ?? kind.defaultUnit
        self.aggregation = aggregation ?? kind.defaultAggregation
        self.higherIsBetter = higherIsBetter
        self.display = display
        self.color = color
        self.showOnDashboard = showOnDashboard
        self.entries = entries.sorted { $0.week < $1.week }
    }

    public func entry(for week: Day) -> Entry? {
        entries.first { $0.week == week }
    }

    public var lastEntry: Entry? { entries.last }

    /// Nom normalisé pour la détection des doublons.
    public var normalizedName: String { Metric.normalize(name) }

    public static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

/// Périodes proposées sur le tableau de synthèse.
public enum PeriodKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Semaine précédente (dernière semaine écoulée).
    case pwk
    /// 4 dernières semaines.
    case l4w
    /// Trimestre fiscal à date.
    case qtd
    /// Exercice fiscal à date.
    case ytd

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .pwk: return "PWK"
        case .l4w: return "L4W"
        case .qtd: return "QTD"
        case .ytd: return "YTD"
        }
    }

    public var label: String {
        switch self {
        case .pwk: return L10n.tr("Semaine précédente", "Previous week")
        case .l4w: return L10n.tr("4 dernières semaines", "Last 4 weeks")
        case .qtd: return L10n.tr("Trimestre à date", "Quarter to date")
        case .ytd: return L10n.tr("Exercice à date", "Year to date")
        }
    }
}

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, fr, en
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .system: return L10n.tr("Langue du système", "System language")
        case .fr: return "Français"
        case .en: return "English"
        }
    }
}

/// Réglages de l'app.
public struct AppSettings: Codable, Hashable, Sendable {
    public var calendar: FiscalCalendar
    public var period: PeriodKind
    public var language: AppLanguage

    public init(calendar: FiscalCalendar = .standard, period: PeriodKind = .pwk, language: AppLanguage = .system) {
        self.calendar = calendar
        self.period = period
        self.language = language
    }
}

/// Contenu du fichier de données.
public struct AppData: Codable, Hashable, Sendable {
    public static let currentVersion = 1
    public var version: Int
    public var settings: AppSettings
    public var metrics: [Metric]

    public init(settings: AppSettings = AppSettings(), metrics: [Metric] = []) {
        version = AppData.currentVersion
        self.settings = settings
        self.metrics = metrics
    }
}
