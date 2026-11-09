import XCTest
@testable import MetrixatorCore

final class DayTests: XCTestCase {
    func testWeekdays() {
        XCTAssertEqual(Day(1970, 1, 1).weekday, 5) // jeudi
        XCTAssertEqual(Day(2026, 11, 9).weekday, 2) // lundi
        XCTAssertEqual(Day(2026, 9, 26).weekday, 7) // samedi
        XCTAssertEqual(Day(1969, 12, 28).weekday, 1) // dimanche (avant l'époque)
    }

    func testArithmeticAndNormalization() {
        XCTAssertEqual(Day(2026, 1, 32), Day(2026, 2, 1))
        XCTAssertEqual(Day(2024, 2, 28).adding(days: 1), Day(2024, 2, 29))
        XCTAssertEqual(Day(2026, 12, 31).adding(days: 1), Day(2027, 1, 1))
        XCTAssertEqual(Day(2026, 3, 1) - Day(2026, 2, 1), 28)
        XCTAssertEqual(Day.lastDay(ofMonth: 2, year: 2028), Day(2028, 2, 29))
    }

    func testISO() throws {
        XCTAssertEqual(Day(2026, 11, 1).iso, "2026-11-01")
        XCTAssertEqual(Day(iso: "2026-11-01"), Day(2026, 11, 1))
        XCTAssertNil(Day(iso: "2026-02-30"))
        XCTAssertNil(Day(iso: "01/11/2026"))
        let data = try JSONEncoder().encode([Day(2026, 1, 5)])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-01-05\"]")
        XCTAssertEqual(try JSONDecoder().decode([Day].self, from: data), [Day(2026, 1, 5)])
    }
}

final class FiscalCalendarTests: XCTestCase {
    let cal = FiscalCalendar.standard // fin = dernier samedi de septembre, semaines dimanche → samedi

    func testFiscalYearBoundaries() {
        XCTAssertEqual(cal.endOfFiscalYear(2026), Day(2026, 9, 26))
        XCTAssertEqual(cal.startOfFiscalYear(2027), Day(2026, 9, 27))
        XCTAssertEqual(cal.endOfFiscalYear(2027), Day(2027, 9, 25))
        XCTAssertEqual(cal.startOfFiscalYear(2026), Day(2025, 9, 28))
        XCTAssertEqual(cal.weeksInFiscalYear(2026), 52)
        XCTAssertEqual(cal.weeksInFiscalYear(2023), 53) // année longue
        XCTAssertEqual(cal.fiscalYear(containing: Day(2026, 9, 26)), 2026)
        XCTAssertEqual(cal.fiscalYear(containing: Day(2026, 9, 27)), 2027)
        XCTAssertEqual(cal.fiscalYear(containing: Day(2027, 1, 15)), 2027)
    }

    func testWeeksAndQuarters() {
        let w = cal.week(containing: Day(2026, 11, 9))
        XCTAssertEqual(w.fiscalYear, 2027)
        XCTAssertEqual(w.index, 7)
        XCTAssertEqual(w.start, Day(2026, 11, 8))
        XCTAssertEqual(w.end, Day(2026, 11, 14))

        let pwk = cal.previousWeek(today: Day(2026, 11, 9))
        XCTAssertEqual(pwk.index, 6)
        XCTAssertEqual(pwk.start, Day(2026, 11, 1))

        XCTAssertEqual(cal.week(fiscalYear: 2027, index: 13)!.quarter, 1)
        XCTAssertEqual(cal.week(fiscalYear: 2027, index: 14)!.quarter, 2)
        XCTAssertEqual(cal.firstWeek(ofQuarter: 2, fiscalYear: 2027).start, Day(2026, 12, 27))
        XCTAssertEqual(cal.week(fiscalYear: 2023, index: 53)!.quarter, 4)
        XCTAssertEqual(cal.weeksInQuarter(4, fiscalYear: 2023), 14)
        XCTAssertNil(cal.week(fiscalYear: 2027, index: 53))

        XCTAssertEqual(cal.sameWeekLastYear(pwk)?.start, Day(2025, 11, 2))
        XCTAssertEqual(cal.trailingWeeks(4, endingAt: pwk).map(\.index), [3, 4, 5, 6])
        // Passage d'exercice.
        let first = cal.week(fiscalYear: 2027, index: 1)!
        XCTAssertEqual(cal.week(offset: -1, from: first).fiscalYear, 2026)
        XCTAssertEqual(cal.week(offset: -1, from: first).index, 52)
    }

    func testCustomCalendar() {
        // Exercice qui finit le dernier dimanche de décembre, semaines du lundi au dimanche.
        let c = FiscalCalendar(yearEndMonth: 12, firstWeekday: 2)
        XCTAssertEqual(c.endOfFiscalYear(2026), Day(2026, 12, 27))
        XCTAssertEqual(c.startOfFiscalYear(2027), Day(2026, 12, 28))
        XCTAssertEqual(c.week(containing: Day(2027, 1, 3)).start.weekday, 2)
        for fy in 2000...2040 {
            let n = c.weeksInFiscalYear(fy)
            XCTAssertTrue(n == 52 || n == 53)
        }
    }
}
