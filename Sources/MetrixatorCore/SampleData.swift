import Foundation

/// Données d'exemple fictives (anonymes) : 22 résultats d'un point de vente imaginaire,
/// avec l'historique hebdomadaire de l'exercice précédent et de l'exercice en cours.
public enum SampleData {
    struct Spec {
        let name: String
        let details: String
        let kind: ValueKind
        let unit: String?
        let aggregation: Aggregation?
        let base: Double
        /// Croissance N vs N-1 : en % (volumes) ou en points (taux/scores).
        let growth: Double
        /// Amplitude de la saisonnalité (0 = aucune).
        let seasonality: Double
        let noise: Double
        let decimals: Int
        let higherIsBetter: Bool
        let display: DisplayStyle
        let color: MetricColor
        /// Nombre de semaines récentes non saisies (pour illustrer la saisie à faire).
        var missingRecentWeeks = 0
        var hasData = true
    }

    static var specs: [Spec] {
        let fr = L10n.current != .en
        func t(_ a: String, _ b: String) -> String { fr ? a : b }
        return [
            Spec(name: t("Chiffre d'affaires total", "Total revenue"), details: t("CA TTC de la semaine, tous canaux.", "Weekly revenue incl. tax, all channels."),
                 kind: .currency, unit: "€", aggregation: nil, base: 420_000, growth: 5, seasonality: 1, noise: 0.05, decimals: 0,
                 higherIsBetter: true, display: .line, color: .blue),
            Spec(name: t("CA Services", "Services revenue"), details: t("Garanties, abonnements et prestations.", "Warranties, subscriptions and services."),
                 kind: .currency, unit: "€", aggregation: nil, base: 38_000, growth: 9, seasonality: 0.6, noise: 0.06, decimals: 0,
                 higherIsBetter: true, display: .bars, color: .purple),
            Spec(name: t("CA Accessoires", "Accessories revenue"), details: "", kind: .currency, unit: "€", aggregation: nil,
                 base: 52_000, growth: 2, seasonality: 1.1, noise: 0.07, decimals: 0, higherIsBetter: true, display: .number, color: .teal),
            Spec(name: t("CA Entreprises", "Business revenue"), details: t("Ventes aux clients professionnels.", "Sales to business customers."),
                 kind: .currency, unit: "€", aggregation: nil, base: 61_000, growth: 12, seasonality: 0.3, noise: 0.12, decimals: 0,
                 higherIsBetter: true, display: .versusLastYear, color: .indigo),
            Spec(name: t("Panier moyen", "Average basket"), details: "", kind: .currency, unit: "€", aggregation: .average,
                 base: 182, growth: 1.5, seasonality: 0.15, noise: 0.03, decimals: 1, higherIsBetter: true, display: .number, color: .orange),
            Spec(name: t("Ventes smartphones", "Smartphone sales"), details: "", kind: .units, unit: t("unités", "units"), aggregation: nil,
                 base: 1_450, growth: 3, seasonality: 1, noise: 0.06, decimals: 0, higherIsBetter: true, display: .bars, color: .blue),
            Spec(name: t("Ventes ordinateurs", "Computer sales"), details: "", kind: .units, unit: t("unités", "units"), aggregation: nil,
                 base: 380, growth: -4, seasonality: 0.8, noise: 0.08, decimals: 0, higherIsBetter: true, display: .line, color: .graphite),
            Spec(name: t("Ventes tablettes", "Tablet sales"), details: "", kind: .units, unit: t("unités", "units"), aggregation: nil,
                 base: 410, growth: 1, seasonality: 0.9, noise: 0.08, decimals: 0, higherIsBetter: true, display: .number, color: .pink),
            Spec(name: t("Ventes montres", "Watch sales"), details: "", kind: .units, unit: t("unités", "units"), aggregation: nil,
                 base: 520, growth: 7, seasonality: 1.2, noise: 0.08, decimals: 0, higherIsBetter: true, display: .bars, color: .red),
            Spec(name: t("Visiteurs", "Visitors"), details: t("Compteur d'entrées du magasin.", "Store door counter."),
                 kind: .units, unit: t("visiteurs", "visitors"), aggregation: nil, base: 21_500, growth: -2, seasonality: 0.8, noise: 0.05, decimals: 0,
                 higherIsBetter: true, display: .line, color: .green),
            Spec(name: t("Taux de conversion", "Conversion rate"), details: t("Transactions / visiteurs.", "Transactions / visitors."),
                 kind: .percent, unit: "%", aggregation: nil, base: 11.5, growth: 0.6, seasonality: 0.1, noise: 0.04, decimals: 1,
                 higherIsBetter: true, display: .yoy, color: .teal),
            Spec(name: t("Taux d'attachement accessoires", "Accessory attach rate"), details: "",
                 kind: .percent, unit: "%", aggregation: nil, base: 38, growth: 1.2, seasonality: 0.05, noise: 0.04, decimals: 1,
                 higherIsBetter: true, display: .number, color: .purple),
            Spec(name: "NPS", details: t("Net Promoter Score des enquêtes clients.", "Net Promoter Score from customer surveys."),
                 kind: .score, unit: "", aggregation: nil, base: 72, growth: 2, seasonality: -0.04, noise: 0.03, decimals: 1,
                 higherIsBetter: true, display: .line, color: .green),
            Spec(name: t("Reprises d'appareils", "Trade-ins"), details: "", kind: .units, unit: t("appareils", "devices"), aggregation: nil,
                 base: 160, growth: 18, seasonality: 0.7, noise: 0.1, decimals: 0, higherIsBetter: true, display: .line, color: .yellow),
            Spec(name: t("Financements souscrits", "Financing plans"), details: "", kind: .units, unit: t("contrats", "plans"), aggregation: nil,
                 base: 210, growth: 6, seasonality: 1, noise: 0.09, decimals: 0, higherIsBetter: true, display: .bars, color: .orange),
            Spec(name: t("Rendez-vous support", "Support appointments"), details: "", kind: .units, unit: t("rendez-vous", "appointments"), aggregation: nil,
                 base: 640, growth: 4, seasonality: 0.3, noise: 0.06, decimals: 0, higherIsBetter: true, display: .line, color: .indigo),
            Spec(name: t("Délai moyen de réparation", "Average repair time"), details: t("Plus bas = mieux.", "Lower is better."),
                 kind: .units, unit: t("jours", "days"), aggregation: .average, base: 2.4, growth: -8, seasonality: 0.4, noise: 0.07, decimals: 2,
                 higherIsBetter: false, display: .number, color: .red),
            Spec(name: t("Participants aux ateliers", "Workshop attendees"), details: "", kind: .units, unit: t("participants", "attendees"), aggregation: nil,
                 base: 310, growth: 15, seasonality: 0.4, noise: 0.1, decimals: 0, higherIsBetter: true, display: .bars, color: .pink),
            Spec(name: t("Réparations le jour même", "Same-day repairs"), details: "", kind: .percent, unit: "%", aggregation: nil,
                 base: 68, growth: 3, seasonality: -0.05, noise: 0.03, decimals: 1, higherIsBetter: true, display: .yoy, color: .blue),
            Spec(name: t("Abonnements souscrits", "Subscriptions sold"), details: "", kind: .units, unit: t("abonnements", "subscriptions"), aggregation: nil,
                 base: 290, growth: 10, seasonality: 0.6, noise: 0.08, decimals: 0, higherIsBetter: true, display: .versusLastYear, color: .purple),
            Spec(name: t("Heures de formation équipe", "Team training hours"), details: t("Dernière semaine pas encore saisie.", "Last week not entered yet."),
                 kind: .units, unit: "h", aggregation: nil, base: 95, growth: 0, seasonality: -0.3, noise: 0.15, decimals: 0,
                 higherIsBetter: true, display: .number, color: .graphite, missingRecentWeeks: 1),
            Spec(name: t("Avis clients publiés", "Customer reviews posted"), details: t("Nouveau résultat : aucune donnée pour l'instant.", "New result: no data yet."),
                 kind: .units, unit: t("avis", "reviews"), aggregation: nil, base: 0, growth: 0, seasonality: 0, noise: 0, decimals: 0,
                 higherIsBetter: true, display: .number, color: .yellow, hasData: false),
        ]
    }

    /// Profil saisonnier selon le rang de la semaine dans l'exercice (début fin septembre) :
    /// pic des fêtes (nov.–déc.), creux de janvier–février, rentrée en août–septembre.
    static func season(_ index: Int) -> Double {
        switch index {
        case 8: return 0.15
        case 9: return 0.45   // Black Friday
        case 10: return 0.2
        case 11: return 0.3
        case 12: return 0.55
        case 13: return 0.6   // Noël
        case 14: return 0.05
        case 15...22: return -0.15
        case 46...52: return 0.12
        default: return 0
        }
    }

    struct Random {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53)
        }
        /// Valeur dans [-1, 1].
        mutating func symmetric() -> Double { next() * 2 - 1 }
    }

    static func round(_ v: Double, _ decimals: Int) -> Double {
        let f = pow(10.0, Double(decimals))
        return (v * f).rounded() / f
    }

    /// Construit le jeu d'exemple : exercice précédent complet + exercice en cours jusqu'à la dernière semaine terminée.
    public static func make(today: Day, calendar cal: FiscalCalendar = .standard) -> AppData {
        let last = cal.previousWeek(today: today)
        let first = cal.week(fiscalYear: last.fiscalYear - 1, index: 1)!
        let weeks = cal.weeks(from: first, to: last)

        var metrics: [Metric] = []
        for (n, spec) in specs.enumerated() {
            var rng = Random(state: UInt64(n + 1) &* 0x9E37_79B9_7F4A_7C15)
            var entries: [Entry] = []
            if spec.hasData {
                let usable = weeks.dropLast(spec.missingRecentWeeks)
                for w in usable {
                    let isCurrentYear = w.fiscalYear == last.fiscalYear
                    let s = season(w.index) * spec.seasonality
                    let noise = rng.symmetric() * spec.noise
                    var value: Double
                    var manual: Double?
                    if spec.kind.comparesInPoints {
                        value = spec.base * (1 + s * 0.3 + noise * 0.5) + (isCurrentYear ? spec.growth : 0)
                        if !isCurrentYear { manual = round(spec.growth * 0.6 + rng.symmetric() * 1.2, 1) }
                    } else {
                        value = spec.base * (1 + s) * (1 + noise) * (isCurrentYear ? 1 + spec.growth / 100 : 1)
                        if !isCurrentYear { manual = round(spec.growth * 0.7 + rng.symmetric() * 5, 1) }
                    }
                    value = round(value, spec.decimals)
                    entries.append(Entry(week: w.start, value: value, manualYoY: manual))
                }
            }
            let id = UUID(uuidString: String(format: "5A3B1E00-0000-4000-8000-%012d", n + 1))!
            metrics.append(Metric(id: id, name: spec.name, details: spec.details, kind: spec.kind, unit: spec.unit,
                                  aggregation: spec.aggregation, higherIsBetter: spec.higherIsBetter,
                                  display: spec.display, color: spec.color, entries: entries))
        }
        return AppData(settings: AppSettings(calendar: cal), metrics: metrics)
    }
}
