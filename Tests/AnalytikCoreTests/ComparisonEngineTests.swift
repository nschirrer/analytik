import XCTest
@testable import AnalytikCore

final class ComparisonEngineTests: XCTestCase {
    func testComparePeriods() throws {
        let report = try Fixtures.subChannelReport()
        let table = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .nbl))
        let comparison = ComparisonEngine.comparePeriods(table, a: Fixtures.week(13).id, b: Fixtures.week(1).id)
        XCTAssertEqual(comparison.titleA, "FY26 Q3 W13")
        XCTAssertEqual(comparison.titleB, "FY26 Q3 W1")
        XCTAssertTrue(comparison.showsDeltaPercent)
        let total = try XCTUnwrap(comparison.rows.first { $0.id == "TOTAL" })
        XCTAssertEqual(total.a, 394)
        XCTAssertEqual(total.b, 360)
        XCTAssertEqual(total.delta, 34)
        XCTAssertEqual(try XCTUnwrap(total.deltaPct), 34.0 / 360.0, accuracy: 1e-9)
    }

    func testCompareSeries() throws {
        let report = try Fixtures.subChannelReport()
        let table = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .nbl))
        let comparison = ComparisonEngine.compareSeries(table, a: "RP - Retail POS", b: "RW - RETAIL WEB")
        XCTAssertEqual(comparison.rows.count, 13)
        XCTAssertEqual(comparison.rowsTitle, "Période")
        let w1 = try XCTUnwrap(comparison.rows.first)
        XCTAssertEqual(w1.label, "FY26 Q3 W1")
        XCTAssertEqual(w1.a, 210)
        XCTAssertEqual(w1.b, 121)
        XCTAssertEqual(w1.delta, 89)
    }

    func testRatioMetricsHaveNoDeltaPercent() throws {
        let report = try Fixtures.subChannelReport()
        let table = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .mix))
        let comparison = ComparisonEngine.comparePeriods(table, a: Fixtures.week(2).id, b: Fixtures.week(1).id)
        XCTAssertFalse(comparison.showsDeltaPercent)
        let pos = try XCTUnwrap(comparison.rows.first { $0.id == "RP - Retail POS" })
        XCTAssertNotNil(pos.delta)
        XCTAssertNil(pos.deltaPct)
    }

    func testMissingValuesAndZeroDenominator() {
        let row = ComparisonEngine.makeRow(id: "x", label: "x", a: 10, b: 0, metric: .nbl, isTotal: false)
        XCTAssertEqual(row.delta, 10)
        XCTAssertNil(row.deltaPct)
        let missing = ComparisonEngine.makeRow(id: "y", label: "y", a: nil, b: 5, metric: .nbl, isTotal: false)
        XCTAssertNil(missing.delta)
        XCTAssertNil(missing.deltaPct)
        let negative = ComparisonEngine.makeRow(id: "z", label: "z", a: 5, b: -10, metric: .nbl, isTotal: false)
        XCTAssertEqual(negative.deltaPct, 1.5)
    }

    func testCurrentVsLastYear() throws {
        let report = try Fixtures.subChannelReport()
        let comparison = ComparisonEngine.currentVsLastYear(reports: [report], query: PivotQuery(metric: .mix))
        XCTAssertEqual(comparison.metric, .nbl)
        let total = try XCTUnwrap(comparison.rows.first { $0.id == "TOTAL" })
        XCTAssertEqual(total.a, 4595)
        XCTAssertEqual(total.b, 3513)
        XCTAssertEqual(try XCTUnwrap(total.deltaPct), 4595.0 / 3513.0 - 1, accuracy: 1e-9)
        let unknownID = ComparisonEngine.comparePeriods(PivotTable.empty, a: "a", b: "b")
        XCTAssertTrue(unknownID.isEmpty)
    }
}
