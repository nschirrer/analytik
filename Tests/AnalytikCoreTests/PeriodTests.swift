import XCTest
@testable import AnalytikCore

final class PeriodTests: XCTestCase {
    func testLabelsAndIDs() {
        let w1 = Period.week(fiscalYear: 2026, quarter: 3, week: 1)
        XCTAssertEqual(w1.id, "FY2026Q3W01")
        XCTAssertEqual(w1.label, "FY26 Q3 W1")
        XCTAssertEqual(w1.shortLabel, "W1")
        XCTAssertEqual(w1.granularity, .week)

        let q2 = Period.quarter(fiscalYear: 2026, quarter: 2)
        XCTAssertEqual(q2.id, "FY2026Q2")
        XCTAssertEqual(q2.label, "FY26 Q2")
        XCTAssertEqual(q2.shortLabel, "Q2 FY26")
        XCTAssertEqual(q2.granularity, .quarter)

        let other = Period.opaque(label: "Sept", order: 7)
        XCTAssertEqual(other.label, "Sept")
        XCTAssertNil(other.granularity)
    }

    func testOrdering() {
        let w1 = Period.week(fiscalYear: 2026, quarter: 3, week: 1)
        let w13 = Period.week(fiscalYear: 2026, quarter: 3, week: 13)
        let q2 = Period.quarter(fiscalYear: 2026, quarter: 2)
        let q3 = Period.quarter(fiscalYear: 2026, quarter: 3)
        let other = Period.opaque(label: "X", order: 0)
        let sorted = [other, q3, w13, q2, w1].sorted()
        XCTAssertEqual(sorted, [q2, w1, w13, q3, other])
    }
}
