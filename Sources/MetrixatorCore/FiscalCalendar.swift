import Foundation

/// Semaine fiscale : identifiée par l'exercice (nommé d'après l'année civile de fin)
/// et son rang (1…52, ou 53 les années longues).
public struct FiscalWeek: Hashable, Comparable, Sendable {
    public let fiscalYear: Int
    public let index: Int
    /// Premier jour de la semaine.
    public let start: Day

    public var end: Day { start.adding(days: 6) }

    /// Trimestre fiscal (1…4) : 13 semaines par trimestre, la 53e semaine éventuelle va au T4.
    public var quarter: Int { min(4, (index - 1) / 13 + 1) }

    public static func < (lhs: FiscalWeek, rhs: FiscalWeek) -> Bool { lhs.start < rhs.start }
}

/// Calendrier fiscal « 52/53 semaines » réglable.
///
/// Règle : l'exercice FY N se termine le dernier jour de semaine (veille de `firstWeekday`)
/// du mois `yearEndMonth` de l'année civile N. Exemple par défaut : fin = dernier samedi
/// de septembre, semaines du dimanche au samedi (FY27 = 27 sept. 2026 → 25 sept. 2027).
public struct FiscalCalendar: Codable, Hashable, Sendable {
    /// Mois de clôture de l'exercice (1…12).
    public var yearEndMonth: Int
    /// Premier jour de la semaine : 1 = dimanche, 2 = lundi … 7 = samedi.
    public var firstWeekday: Int

    public init(yearEndMonth: Int = 9, firstWeekday: Int = 1) {
        self.yearEndMonth = min(max(yearEndMonth, 1), 12)
        self.firstWeekday = min(max(firstWeekday, 1), 7)
    }

    public static let standard = FiscalCalendar()

    /// Jour de fin de semaine (veille du premier jour).
    var lastWeekday: Int { firstWeekday == 1 ? 7 : firstWeekday - 1 }

    /// Dernier jour de l'exercice `fy`.
    public func endOfFiscalYear(_ fy: Int) -> Day {
        let last = Day.lastDay(ofMonth: yearEndMonth, year: fy)
        let back = (last.weekday - lastWeekday + 7) % 7
        return last.adding(days: -back)
    }

    /// Premier jour de l'exercice `fy`.
    public func startOfFiscalYear(_ fy: Int) -> Day { endOfFiscalYear(fy - 1).adding(days: 1) }

    public func weeksInFiscalYear(_ fy: Int) -> Int {
        (endOfFiscalYear(fy) - startOfFiscalYear(fy) + 1) / 7
    }

    public func fiscalYear(containing day: Day) -> Int {
        var fy = day.year
        if day > endOfFiscalYear(fy) { fy += 1 }
        if day < startOfFiscalYear(fy) { fy -= 1 }
        return fy
    }

    public func week(containing day: Day) -> FiscalWeek {
        let fy = fiscalYear(containing: day)
        let start = startOfFiscalYear(fy)
        let idx = (day - start) / 7 + 1
        return FiscalWeek(fiscalYear: fy, index: idx, start: start.adding(days: (idx - 1) * 7))
    }

    /// Semaine `index` de l'exercice `fy`, ou `nil` si elle n'existe pas (p. ex. 53e semaine).
    public func week(fiscalYear fy: Int, index: Int) -> FiscalWeek? {
        guard index >= 1, index <= weeksInFiscalYear(fy) else { return nil }
        return FiscalWeek(fiscalYear: fy, index: index, start: startOfFiscalYear(fy).adding(days: (index - 1) * 7))
    }

    public func week(offset: Int, from week: FiscalWeek) -> FiscalWeek {
        self.week(containing: week.start.adding(days: 7 * offset))
    }

    /// Dernière semaine entièrement écoulée (« PWK ») à la date donnée.
    public func previousWeek(today: Day) -> FiscalWeek {
        week(offset: -1, from: week(containing: today))
    }

    /// Même semaine fiscale l'année précédente (même rang), si elle existe.
    public func sameWeekLastYear(_ week: FiscalWeek) -> FiscalWeek? {
        self.week(fiscalYear: week.fiscalYear - 1, index: week.index)
    }

    public func firstWeek(ofQuarter q: Int, fiscalYear fy: Int) -> FiscalWeek {
        self.week(fiscalYear: fy, index: (q - 1) * 13 + 1)!
    }

    public func weeksInQuarter(_ q: Int, fiscalYear fy: Int) -> Int {
        q < 4 ? 13 : weeksInFiscalYear(fy) - 39
    }

    /// Toutes les semaines de `from` à `to` incluses.
    public func weeks(from: FiscalWeek, to: FiscalWeek) -> [FiscalWeek] {
        guard from <= to else { return [] }
        let n = (to.start - from.start) / 7
        return (0...n).map { week(containing: from.start.adding(days: 7 * $0)) }
    }

    /// Les `count` semaines se terminant par `last` (incluse).
    public func trailingWeeks(_ count: Int, endingAt last: FiscalWeek) -> [FiscalWeek] {
        guard count > 0 else { return [] }
        return weeks(from: week(offset: -(count - 1), from: last), to: last)
    }
}
