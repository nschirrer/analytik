import XCTest
@testable import AnalytikCore

final class PeriodParserTests: XCTestCase {
    func testExplicitWeekSetsContextForBareWeeks() {
        let periods = PeriodParser.parseHeader(["FY26Q3_W1", "W2", "W13"])
        XCTAssertEqual(periods, [
            .week(fiscalYear: 2026, quarter: 3, week: 1),
            .week(fiscalYear: 2026, quarter: 3, week: 2),
            .week(fiscalYear: 2026, quarter: 3, week: 13),
        ])
    }

    func testBareWeekWithoutContextIsOpaque() {
        let periods = PeriodParser.parseHeader(["W2"])
        XCTAssertEqual(periods, [.opaque(label: "W2", order: 0)])
    }

    func testQuarterLabels() {
        let periods = PeriodParser.parseHeader(["26'Q2", "FY26Q3", "2026 Q4", "FY2027Q1"])
        XCTAssertEqual(periods, [
            .quarter(fiscalYear: 2026, quarter: 2),
            .quarter(fiscalYear: 2026, quarter: 3),
            .quarter(fiscalYear: 2026, quarter: 4),
            .quarter(fiscalYear: 2027, quarter: 1),
        ])
    }

    func testBareQuarterInheritsFiscalYear() {
        let periods = PeriodParser.parseHeader(["FY26Q3_W1", "Q3"])
        XCTAssertEqual(periods[1], .quarter(fiscalYear: 2026, quarter: 3))
    }

    func testContextSwitchesOnNewExplicitWeek() {
        let periods = PeriodParser.parseHeader(["FY26Q4_W12", "W13", "FY27Q1_W1", "W2"])
        XCTAssertEqual(periods[1], .week(fiscalYear: 2026, quarter: 4, week: 13))
        XCTAssertEqual(periods[3], .week(fiscalYear: 2027, quarter: 1, week: 2))
    }

    func testUnknownLabelsAreOpaqueAndOrdered() {
        let periods = PeriodParser.parseHeader(["Sept", "Oct"])
        XCTAssertEqual(periods, [.opaque(label: "Sept", order: 0), .opaque(label: "Oct", order: 1)])
        XCTAssertTrue(periods[0] < periods[1])
    }

    func testSampleHeader() {
        var labels = ["FY26Q3_W1"]
        labels += (2...13).map { "W\($0)" }
        labels += ["26'Q2", "26'Q3"]
        let periods = PeriodParser.parseHeader(labels)
        XCTAssertEqual(periods.count, 15)
        XCTAssertEqual(periods.filter { $0.granularity == .week }.count, 13)
        XCTAssertEqual(periods.filter { $0.granularity == .quarter }.count, 2)
        XCTAssertEqual(periods.last, .quarter(fiscalYear: 2026, quarter: 3))
        XCTAssertEqual(periods.sorted().first, .quarter(fiscalYear: 2026, quarter: 2))
    }
}
