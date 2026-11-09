import Foundation

/// Localisation minimaliste français / anglais.
/// Les textes sont écrits côte à côte dans le code : `L10n.tr("Bonjour", "Hello")`.
public enum L10n {
    public enum Language: String, Sendable { case fr, en }

    /// Langue active. Par défaut : celle du système (français si non reconnue).
    nonisolated(unsafe) public static var current: Language = systemLanguage

    public static var systemLanguage: Language {
        let first = Locale.preferredLanguages.first?.lowercased() ?? "fr"
        return first.hasPrefix("en") ? .en : .fr
    }

    public static func apply(_ setting: AppLanguage) {
        switch setting {
        case .system: current = systemLanguage
        case .fr: current = .fr
        case .en: current = .en
        }
    }

    public static func tr(_ fr: String, _ en: String) -> String {
        current == .en ? en : fr
    }

    static let frMonths = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
    static let enMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    public static func monthName(_ m: Int) -> String {
        let i = min(max(m, 1), 12) - 1
        return current == .en ? enMonths[i] : frMonths[i]
    }

    public static func fullMonthName(_ m: Int) -> String {
        let fr = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
        let en = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        let i = min(max(m, 1), 12) - 1
        return current == .en ? en[i] : fr[i]
    }

    public static func weekdayName(_ w: Int) -> String {
        let fr = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        let en = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let i = min(max(w, 1), 7) - 1
        return current == .en ? en[i] : fr[i]
    }

    /// « 1 nov. 2026 » / « Nov 1, 2026 ».
    public static func date(_ d: Day, withYear: Bool = true) -> String {
        if current == .en {
            return "\(monthName(d.month)) \(d.day)" + (withYear ? ", \(d.year)" : "")
        }
        return "\(d.day) \(monthName(d.month))" + (withYear ? " \(d.year)" : "")
    }

    /// « 1–7 nov. » / « Nov 1–7 », sur deux mois si besoin.
    public static func range(_ a: Day, _ b: Day) -> String {
        if a.month == b.month {
            return current == .en ? "\(monthName(a.month)) \(a.day)–\(b.day)" : "\(a.day)–\(b.day) \(monthName(a.month))"
        }
        return "\(date(a, withYear: false)) – \(date(b, withYear: false))"
    }

    /// « FY27 » pour l'exercice 2027.
    public static func fiscalYear(_ fy: Int) -> String { String(format: "FY%02d", fy % 100) }

    /// « S6 FY27 » / « W6 FY27 ».
    public static func weekShort(_ w: FiscalWeek) -> String {
        "\(tr("S", "W"))\(w.index) \(fiscalYear(w.fiscalYear))"
    }

    /// « S6 FY27 · 1–7 nov. »
    public static func weekLong(_ w: FiscalWeek) -> String {
        "\(weekShort(w)) · \(range(w.start, w.end))"
    }

    /// Légende d'une période sur les tuiles : « S6 FY27 · 1–7 nov. », « S3–S6 · 11 oct. – 7 nov. »,
    /// « T1 FY27 · à S6 », « FY27 · à S6 ».
    public static func periodCaption(_ kind: PeriodKind, reference ref: FiscalWeek, calendar cal: FiscalCalendar) -> String {
        switch kind {
        case .pwk:
            return weekLong(ref)
        case .l4w:
            let first = cal.week(offset: -3, from: ref)
            let label = first.fiscalYear == ref.fiscalYear
                ? "\(tr("S", "W"))\(first.index)–\(ref.index)"
                : "\(weekShort(first))–\(weekShort(ref))"
            return "\(label) · \(range(first.start, ref.end))"
        case .qtd:
            return "\(tr("T", "Q"))\(ref.quarter) \(fiscalYear(ref.fiscalYear)) · \(tr("à S", "to W"))\(ref.index)"
        case .ytd:
            return "\(fiscalYear(ref.fiscalYear)) · \(tr("à S", "to W"))\(ref.index)"
        }
    }
}
