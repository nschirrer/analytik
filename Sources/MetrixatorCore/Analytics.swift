import Foundation

/// Origine d'une progression Y/Y.
public enum YoYSource: String, Sendable {
    /// Calculée à partir de la même semaine de l'an dernier présente dans l'app.
    case computed
    /// Saisie à la main.
    case manual
    /// Période : mélange des deux.
    case mixed
}

/// Point d'une série hebdomadaire (pour les graphiques).
public struct SeriesPoint: Identifiable, Hashable, Sendable {
    public let week: FiscalWeek
    /// Rang du point dans la série (axe X).
    public let position: Int
    public let value: Double?
    public let lastYear: Double?
    public var id: Int { position }
}

/// Résumé d'un résultat sur une période.
public struct PeriodSummary: Hashable, Sendable {
    public let kind: PeriodKind
    public let weeks: [FiscalWeek]
    /// Valeur agrégée (somme ou moyenne) ; `nil` si aucune donnée sur la période.
    public let value: Double?
    public let weeksWithData: Int
    /// Progression vs l'an dernier (en % ou en points selon la nature).
    public let yoy: Double?
    public let yoySource: YoYSource?
    /// Valeur de l'an dernier sur les semaines comparables.
    public let lastYearValue: Double?
    /// Période précédente comparable (semaine d'avant, 4 semaines d'avant, trimestre précédent).
    public let previousValue: Double?
    public let change: Double?

    public var first: FiscalWeek? { weeks.first }
    public var last: FiscalWeek? { weeks.last }
    public var isComplete: Bool { weeksWithData == weeks.count }
}

public enum Analytics {
    // MARK: Périodes

    /// Semaines couvertes par la période qui se termine par la semaine de référence (incluse).
    public static func weeks(for kind: PeriodKind, reference ref: FiscalWeek, calendar cal: FiscalCalendar) -> [FiscalWeek] {
        switch kind {
        case .pwk:
            return [ref]
        case .l4w:
            return cal.trailingWeeks(4, endingAt: ref)
        case .qtd:
            return cal.weeks(from: cal.firstWeek(ofQuarter: ref.quarter, fiscalYear: ref.fiscalYear), to: ref)
        case .ytd:
            return cal.weeks(from: cal.week(fiscalYear: ref.fiscalYear, index: 1)!, to: ref)
        }
    }

    /// Période précédente comparable, ou `nil` pour le YTD (la comparaison pertinente est le Y/Y).
    public static func previousWeeks(for kind: PeriodKind, reference ref: FiscalWeek, calendar cal: FiscalCalendar) -> [FiscalWeek]? {
        switch kind {
        case .pwk:
            return [cal.week(offset: -1, from: ref)]
        case .l4w:
            return cal.trailingWeeks(4, endingAt: cal.week(offset: -4, from: ref))
        case .qtd:
            let elapsed = ref.index - (ref.quarter - 1) * 13
            let (pq, pfy) = ref.quarter == 1 ? (4, ref.fiscalYear - 1) : (ref.quarter - 1, ref.fiscalYear)
            let start = cal.firstWeek(ofQuarter: pq, fiscalYear: pfy)
            let count = min(elapsed, cal.weeksInQuarter(pq, fiscalYear: pfy))
            return cal.weeks(from: start, to: cal.week(offset: count - 1, from: start))
        case .ytd:
            return nil
        }
    }

    /// Libellé abrégé de la comparaison avec la période précédente.
    public static func previousLabel(for kind: PeriodKind) -> String? {
        switch kind {
        case .pwk: return L10n.tr("vs sem. préc.", "vs prev. week")
        case .l4w: return L10n.tr("vs 4 sem. préc.", "vs prev. 4 wks")
        case .qtd: return L10n.tr("vs trim. préc.", "vs prev. qtr")
        case .ytd: return nil
        }
    }

    // MARK: Agrégats

    public static func aggregate(_ values: [Double], _ aggregation: Aggregation) -> Double? {
        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return aggregation == .sum ? total : total / Double(values.count)
    }

    /// Progression entre deux valeurs : relative (%) ou en points.
    public static func change(from old: Double?, to new: Double?, inPoints: Bool) -> Double? {
        guard let old, let new else { return nil }
        if inPoints { return new - old }
        guard old != 0 else { return nil }
        return (new / old - 1) * 100
    }

    // MARK: Y/Y

    /// Valeur de l'an dernier pour une semaine : la même semaine de l'exercice précédent si elle est
    /// présente dans l'app, sinon déduite du Y/Y saisi à la main.
    public static func lastYear(of metric: Metric, week: FiscalWeek, calendar cal: FiscalCalendar) -> (value: Double, source: YoYSource)? {
        if let lyWeek = cal.sameWeekLastYear(week), let ly = metric.entry(for: lyWeek.start) {
            return (ly.value, .computed)
        }
        guard let entry = metric.entry(for: week.start), let manual = entry.manualYoY else { return nil }
        if metric.kind.comparesInPoints {
            return (entry.value - manual, .manual)
        }
        guard manual > -100 else { return nil }
        return (entry.value / (1 + manual / 100), .manual)
    }

    /// Progression Y/Y d'une semaine (calculée si possible, sinon saisie).
    public static func weeklyYoY(of metric: Metric, week: FiscalWeek, calendar cal: FiscalCalendar) -> (value: Double, source: YoYSource)? {
        guard let entry = metric.entry(for: week.start) else { return nil }
        if let lyWeek = cal.sameWeekLastYear(week), let ly = metric.entry(for: lyWeek.start) {
            guard let c = change(from: ly.value, to: entry.value, inPoints: metric.kind.comparesInPoints) else { return nil }
            return (c, .computed)
        }
        if let manual = entry.manualYoY { return (manual, .manual) }
        return nil
    }

    // MARK: Résumé de période

    public static func summary(of metric: Metric, period kind: PeriodKind, reference ref: FiscalWeek, calendar cal: FiscalCalendar) -> PeriodSummary {
        let weeks = weeks(for: kind, reference: ref, calendar: cal)
        let values = weeks.compactMap { metric.entry(for: $0.start)?.value }
        let value = aggregate(values, metric.aggregation)

        // Y/Y sur les seules semaines qui ont à la fois une valeur et une référence N-1.
        var current: [Double] = []
        var lastYear: [Double] = []
        var sources = Set<YoYSource>()
        for w in weeks {
            guard let e = metric.entry(for: w.start), let ly = self.lastYear(of: metric, week: w, calendar: cal) else { continue }
            current.append(e.value)
            lastYear.append(ly.value)
            sources.insert(ly.source)
        }
        let lyValue = aggregate(lastYear, metric.aggregation)
        let yoy = change(from: lyValue, to: aggregate(current, metric.aggregation), inPoints: metric.kind.comparesInPoints)
        let source: YoYSource? = sources.isEmpty ? nil : (sources.count > 1 ? .mixed : sources.first)

        var previousValue: Double?
        var delta: Double?
        if let prev = previousWeeks(for: kind, reference: ref, calendar: cal) {
            let prevValues = prev.compactMap { metric.entry(for: $0.start)?.value }
            previousValue = aggregate(prevValues, metric.aggregation)
            // Une somme sur des semaines incomplètes fausserait la comparaison : on ne compare
            // les cumuls que si les deux périodes sont entièrement renseignées.
            let comparable = metric.aggregation == .average || (prevValues.count == prev.count && values.count == weeks.count)
            if comparable { delta = change(from: previousValue, to: value, inPoints: metric.kind.comparesInPoints) }
        }

        return PeriodSummary(kind: kind, weeks: weeks, value: value, weeksWithData: values.count,
                             yoy: yoy, yoySource: yoy == nil ? nil : source, lastYearValue: lyValue,
                             previousValue: previousValue, change: delta)
    }

    // MARK: Séries pour les graphiques

    /// Semaines affichées sur le graphique d'une tuile selon la période choisie.
    public static func chartWeeks(for kind: PeriodKind, reference ref: FiscalWeek, calendar cal: FiscalCalendar) -> [FiscalWeek] {
        switch kind {
        case .pwk, .l4w: return cal.trailingWeeks(13, endingAt: ref)
        case .qtd: return cal.weeks(from: cal.firstWeek(ofQuarter: ref.quarter, fiscalYear: ref.fiscalYear), to: ref)
        case .ytd: return weeks(for: .ytd, reference: ref, calendar: cal)
        }
    }

    public static func series(of metric: Metric, weeks: [FiscalWeek], calendar cal: FiscalCalendar) -> [SeriesPoint] {
        weeks.enumerated().map { i, w in
            let ly = cal.sameWeekLastYear(w).flatMap { metric.entry(for: $0.start)?.value }
            return SeriesPoint(week: w, position: i, value: metric.entry(for: w.start)?.value, lastYear: ly)
        }
    }

    /// Vrai si la progression est favorable compte tenu du sens du résultat.
    public static func isFavorable(_ change: Double, higherIsBetter: Bool) -> Bool {
        higherIsBetter ? change >= 0 : change <= 0
    }
}
