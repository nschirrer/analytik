import Foundation

/// Jour civil (sans heure ni fuseau horaire). Toute la logique de calendrier
/// travaille sur ce type pour éviter les surprises de fuseau horaire / heure d'été.
public struct Day: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        // Normalise via le nombre de jours (accepte p. ex. le 32 janvier).
        let n = Day.daysFromCivil(year, month, 1) + (day - 1)
        let c = Day.civilFromDays(n)
        self.year = c.0
        self.month = c.1
        self.day = c.2
    }

    public init(daysSinceEpoch n: Int) {
        let c = Day.civilFromDays(n)
        year = c.0
        month = c.1
        day = c.2
    }

    /// Nombre de jours depuis le 1970-01-01.
    public var daysSinceEpoch: Int { Day.daysFromCivil(year, month, day) }

    /// 1 = dimanche … 7 = samedi (convention de `Calendar`).
    public var weekday: Int {
        // 1970-01-01 était un jeudi (5).
        let w = (daysSinceEpoch % 7 + 7) % 7 // 0 = jeudi
        return (w + 4) % 7 + 1
    }

    public func adding(days: Int) -> Day { Day(daysSinceEpoch: daysSinceEpoch + days) }

    public static func - (lhs: Day, rhs: Day) -> Int { lhs.daysSinceEpoch - rhs.daysSinceEpoch }

    public static func < (lhs: Day, rhs: Day) -> Bool { lhs.daysSinceEpoch < rhs.daysSinceEpoch }

    /// Format ISO « 2026-11-01 ».
    public var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public var description: String { iso }

    public init?(iso: String) {
        let parts = iso.trimmingCharacters(in: .whitespaces).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        let candidate = Day(y, m, d)
        guard candidate.year == y, candidate.month == m, candidate.day == d else { return nil }
        self = candidate
    }

    /// Jour courant dans le fuseau horaire de l'appareil.
    public static func today(calendar: Calendar = .current, now: Date = Date()) -> Day {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return Day(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// Date à midi UTC (utile pour les axes de graphiques).
    public var date: Date { Date(timeIntervalSince1970: TimeInterval(daysSinceEpoch) * 86_400 + 43_200) }

    public static func lastDay(ofMonth month: Int, year: Int) -> Day {
        Day(year, month + 1, 1).adding(days: -1)
    }

    // MARK: - Codable (chaîne ISO)

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = Day(iso: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Date invalide : \(s)"))
        }
        self = d
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso)
    }

    // MARK: - Algorithmes de H. Hinnant (calendrier grégorien proleptique)

    static func daysFromCivil(_ y0: Int, _ m0: Int, _ d: Int) -> Int {
        // Normalise le mois.
        var y = y0 + (m0 - 1).floorDiv(12)
        let m = (m0 - 1).floorMod(12) + 1
        y -= m <= 2 ? 1 : 0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (m + 9) % 12
        let doy = (153 * mp + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civilFromDays(_ z0: Int) -> (Int, Int, Int) {
        let z = z0 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? y + 1 : y, m, d)
    }
}

extension Int {
    func floorDiv(_ d: Int) -> Int { let q = self / d; return (self % d != 0 && (self < 0) != (d < 0)) ? q - 1 : q }
    func floorMod(_ d: Int) -> Int { self - floorDiv(d) * d }
}
