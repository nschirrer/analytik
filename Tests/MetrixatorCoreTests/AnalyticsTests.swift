import XCTest
@testable import MetrixatorCore

final class AnalyticsTests: XCTestCase {
    let cal = FiscalCalendar.standard
    lazy var pwk = cal.previousWeek(today: Day(2026, 11, 9)) // S6 FY27, 1–7 nov. 2026

    func week(_ fy: Int, _ i: Int) -> Day { cal.week(fiscalYear: fy, index: i)!.start }

    /// CA : S1…S6 FY27 = 100…150, même période FY26 = 90, 100, 100, 100, 100, 120.
    func revenue() -> Metric {
        let current = [100.0, 110, 120, 130, 140, 150]
        let last = [90.0, 100, 100, 100, 100, 120]
        var entries: [Entry] = []
        for i in 0..<6 {
            entries.append(Entry(week: week(2027, i + 1), value: current[i]))
            entries.append(Entry(week: week(2026, i + 1), value: last[i]))
        }
        return Metric(name: "CA", kind: .currency, entries: entries)
    }

    func testPeriodRanges() {
        XCTAssertEqual(Analytics.weeks(for: .pwk, reference: pwk, calendar: cal).map(\.index), [6])
        XCTAssertEqual(Analytics.weeks(for: .l4w, reference: pwk, calendar: cal).map(\.index), [3, 4, 5, 6])
        XCTAssertEqual(Analytics.weeks(for: .qtd, reference: pwk, calendar: cal).map(\.index), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(Analytics.weeks(for: .ytd, reference: pwk, calendar: cal).count, 6)

        let q2 = cal.week(fiscalYear: 2027, index: 16)!
        XCTAssertEqual(Analytics.weeks(for: .qtd, reference: q2, calendar: cal).map(\.index), [14, 15, 16])
        XCTAssertEqual(Analytics.weeks(for: .ytd, reference: q2, calendar: cal).count, 16)
        XCTAssertEqual(Analytics.previousWeeks(for: .qtd, reference: q2, calendar: cal)?.map(\.index), [1, 2, 3])
        // T1 → T4 de l'exercice précédent.
        let prevQ = Analytics.previousWeeks(for: .qtd, reference: pwk, calendar: cal)!
        XCTAssertEqual(prevQ.map(\.index), [40, 41, 42, 43, 44, 45])
        XCTAssertEqual(prevQ.first?.fiscalYear, 2026)
        XCTAssertNil(Analytics.previousWeeks(for: .ytd, reference: pwk, calendar: cal))
    }

    /// Critère 2 : la progression se calcule correctement.
    func testSumMetricProgressions() {
        let m = revenue()
        let p = Analytics.summary(of: m, period: .pwk, reference: pwk, calendar: cal)
        XCTAssertEqual(p.value, 150)
        XCTAssertEqual(p.yoy!, 25, accuracy: 1e-9)           // 150 / 120 − 1
        XCTAssertEqual(p.yoySource, .computed)
        XCTAssertEqual(p.previousValue, 140)
        XCTAssertEqual(p.change!, 150.0 / 140 * 100 - 100, accuracy: 1e-9)

        let l4w = Analytics.summary(of: m, period: .l4w, reference: pwk, calendar: cal)
        XCTAssertEqual(l4w.value, 540)
        XCTAssertEqual(l4w.yoy!, (540.0 / 420 - 1) * 100, accuracy: 1e-9)
        XCTAssertNil(l4w.change, "4 semaines précédentes incomplètes : pas de comparaison de cumul")

        let qtd = Analytics.summary(of: m, period: .qtd, reference: pwk, calendar: cal)
        XCTAssertEqual(qtd.value, 750)
        XCTAssertEqual(qtd.lastYearValue, 610)
        XCTAssertEqual(qtd.yoy!, (750.0 / 610 - 1) * 100, accuracy: 1e-9)
        XCTAssertTrue(qtd.isComplete)

        let ytd = Analytics.summary(of: m, period: .ytd, reference: pwk, calendar: cal)
        XCTAssertEqual(ytd.value, 750)
        XCTAssertNil(ytd.change)
    }

    func testAverageMetricInPoints() {
        // Taux : S5 = 30 % (Y/Y saisi +1,5 pt), S6 = 32 % (N-1 présent : 31 %).
        let m = Metric(name: "Conversion", kind: .percent, entries: [
            Entry(week: week(2027, 5), value: 30, manualYoY: 1.5),
            Entry(week: week(2027, 6), value: 32, manualYoY: 9), // ignoré : N-1 présent → calculé
            Entry(week: week(2026, 6), value: 31),
        ])
        XCTAssertEqual(m.aggregation, .average)
        let p = Analytics.summary(of: m, period: .pwk, reference: pwk, calendar: cal)
        XCTAssertEqual(p.yoy!, 1, accuracy: 1e-9)
        XCTAssertEqual(p.yoySource, .computed)
        XCTAssertEqual(p.change!, 2, accuracy: 1e-9) // 32 − 30 points

        let l4w = Analytics.summary(of: m, period: .l4w, reference: pwk, calendar: cal)
        XCTAssertEqual(l4w.value!, 31, accuracy: 1e-9)
        XCTAssertEqual(l4w.lastYearValue!, (28.5 + 31) / 2, accuracy: 1e-9)
        XCTAssertEqual(l4w.yoy!, 31 - 29.75, accuracy: 1e-9)
        XCTAssertEqual(l4w.yoySource, .mixed)

        let weekly = Analytics.weeklyYoY(of: m, week: cal.week(fiscalYear: 2027, index: 5)!, calendar: cal)
        XCTAssertEqual(weekly?.value, 1.5)
        XCTAssertEqual(weekly?.source, .manual)
    }

    func testManualRelativeYoY() {
        let m = Metric(name: "Unités", kind: .units, entries: [Entry(week: week(2027, 6), value: 110, manualYoY: 10)])
        let p = Analytics.summary(of: m, period: .pwk, reference: pwk, calendar: cal)
        XCTAssertEqual(p.yoy!, 10, accuracy: 1e-9)
        XCTAssertEqual(p.yoySource, .manual)
        XCTAssertEqual(p.lastYearValue!, 100, accuracy: 1e-9)
    }

    func testEmptyMetricStaysEmpty() {
        let m = Metric(name: "Vide")
        let p = Analytics.summary(of: m, period: .qtd, reference: pwk, calendar: cal)
        XCTAssertNil(p.value)
        XCTAssertNil(p.yoy)
        XCTAssertNil(p.change)
        XCTAssertEqual(p.weeksWithData, 0)
        XCTAssertTrue(Analytics.series(of: m, weeks: [pwk], calendar: cal).allSatisfy { $0.value == nil })
    }

    func testZeroLastYearGivesNoPercentage() {
        let m = Metric(name: "Z", kind: .units, entries: [Entry(week: week(2027, 6), value: 5), Entry(week: week(2026, 6), value: 0)])
        XCTAssertNil(Analytics.summary(of: m, period: .pwk, reference: pwk, calendar: cal).yoy)
    }

    func testSeriesIncludesLastYear() {
        let m = revenue()
        let s = Analytics.series(of: m, weeks: Analytics.chartWeeks(for: .qtd, reference: pwk, calendar: cal), calendar: cal)
        XCTAssertEqual(s.map(\.value), [100, 110, 120, 130, 140, 150])
        XCTAssertEqual(s.map(\.lastYear), [90, 100, 100, 100, 100, 120])
        XCTAssertEqual(Analytics.chartWeeks(for: .pwk, reference: pwk, calendar: cal).count, 13)
    }

    func testFavorable() {
        XCTAssertTrue(Analytics.isFavorable(3, higherIsBetter: true))
        XCTAssertFalse(Analytics.isFavorable(3, higherIsBetter: false))
        XCTAssertTrue(Analytics.isFavorable(-3, higherIsBetter: false))
    }
}
