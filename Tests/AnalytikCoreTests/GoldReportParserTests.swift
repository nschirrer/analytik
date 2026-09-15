import XCTest
@testable import AnalytikCore

final class GoldReportParserTests: XCTestCase {
    func testMetadata() throws {
        let report = try Fixtures.subChannelReport()
        XCTAssertEqual(report.sheetName, "Sub-Channel")
        XCTAssertEqual(report.fileName, "gold-subchannel.xlsx")
        XCTAssertEqual(report.product, "iPhone")
        XCTAssertEqual(report.channel, "Retail")
        XCTAssertEqual(report.store, "R000 - Exemple")
        XCTAssertEqual(report.country, "France")
        XCTAssertEqual(report.type, "REFURB")
        XCTAssertEqual(report.measures, "Net Billings")
        XCTAssertEqual(report.metadataOrder.first, "Product")
        XCTAssertEqual(report.dimension, "Sub-Channel")
    }

    func testStructure() throws {
        let report = try Fixtures.subChannelReport()
        XCTAssertEqual(report.members, ["TOTAL", "RP - Retail POS", "RW - RETAIL WEB", "RB - RETAIL BUSINESS", "RK - RETAIL KIOSK"])
        XCTAssertEqual(report.metrics, ["NBL", "y/y", "LY", "Mix"])
        XCTAssertEqual(report.periods.count, 15)
        XCTAssertEqual(report.periods(of: .week).count, 13)
        XCTAssertEqual(report.periods(of: .quarter).count, 2)
        XCTAssertEqual(report.facts.count, 15 * 15)
        XCTAssertEqual(report.totalMember, "TOTAL")
        XCTAssertEqual(report.leafMembers.count, 4)
        XCTAssertEqual(report.knownMetrics, [.nbl, .yoy, .ly, .mix])
    }

    func testValues() throws {
        let report = try Fixtures.subChannelReport()
        let w1 = Fixtures.week(1)
        let q3 = Period.quarter(fiscalYear: 2026, quarter: 3)
        XCTAssertEqual(report.value(member: "TOTAL", metric: .nbl, period: w1), 360)
        XCTAssertEqual(report.value(member: "TOTAL", metric: .ly, period: w1), 240)
        XCTAssertEqual(report.value(member: "TOTAL", metric: .yoy, period: w1), 0.5)
        XCTAssertEqual(report.value(member: "TOTAL", metric: .nbl, period: q3), 4595)
        XCTAssertEqual(report.value(member: "TOTAL", metric: .nbl, period: .quarter(fiscalYear: 2026, quarter: 2)), 4262)
        XCTAssertEqual(report.value(member: "RP - Retail POS", metric: .nbl, period: w1), 210)
        // '-' devient nil
        XCTAssertNil(report.value(member: "RK - RETAIL KIOSK", metric: .yoy, period: w1))
        XCTAssertEqual(report.value(member: "RK - RETAIL KIOSK", metric: .yoy, period: Fixtures.week(13)), -1)
        // La somme des semaines est égale au total du trimestre.
        let weeks = report.periods(of: .week)
        let sum = weeks.compactMap { report.value(member: "TOTAL", metric: .nbl, period: $0) }.reduce(0, +)
        XCTAssertEqual(sum, 4595)
    }

    func testLastYearEstimate() throws {
        let report = try Fixtures.subChannelReport()
        let w1 = Fixtures.week(1)
        let total = report.lastYear(member: "TOTAL", period: w1)
        XCTAssertEqual(total.value, 240)
        XCTAssertFalse(total.isDerived)
        let pos = report.lastYear(member: "RP - Retail POS", period: w1)
        XCTAssertTrue(pos.isDerived)
        XCTAssertEqual(try XCTUnwrap(pos.value), 210.0 / 1.06, accuracy: 1e-9)
        let kiosk = report.lastYear(member: "RK - RETAIL KIOSK", period: w1)
        XCTAssertNil(kiosk.value)
    }

    func testProductsWorkbookSkipsNotesSheet() throws {
        let report = try Fixtures.productsReport()
        XCTAssertEqual(report.sheetName, "Product")
        XCTAssertEqual(report.dimension, "Product")
        XCTAssertEqual(report.members, ["iPhone", "Mac", "iPad"])
        XCTAssertNil(report.totalMember)
        XCTAssertEqual(report.metrics, ["NBL", "y/y", "LY"])
        XCTAssertEqual(report.periods.count, 5)
        XCTAssertEqual(report.product, "All")
        XCTAssertEqual(report.value(member: "iPhone", metric: .nbl, period: Fixtures.week(1, q: 4)), 400)
        XCTAssertEqual(report.value(member: "Mac", metric: .nbl, period: .quarter(fiscalYear: 2026, quarter: 4)), 500)
    }

    func testParseAllSheetsReturnsOnlyUsableSheets() throws {
        let reports = try GoldReportParser.parseAllSheets(fileURL: try Fixtures.url("gold-products"))
        XCTAssertEqual(reports.map { $0.sheetName }, ["Product"])
    }

    func testGridWithoutHeaderThrows() {
        let grid = SheetGrid(name: "Vide", rows: [["Titre"], [nil, "x"]])
        XCTAssertThrowsError(try GoldReportParser.parse(grid: grid, fileName: "f.xlsx", filePath: "/f.xlsx")) { error in
            XCTAssertEqual(error as? GoldParseError, .noHeaderRow(sheet: "Vide"))
        }
    }

    func testGridParsingDetails() throws {
        let grid = SheetGrid(name: "T", rows: [
            [nil],
            ["Product", nil, "Mac"],
            [nil],
            ["Store", " ", "FY26Q1_W1", "W2", "26'Q1"],
            ["R001 - Un", "NBL", "10", "12", "22"],
            [" ", "LY", "8", "-", "8"],
            ["R002 - Deux", "NBL", "1 200", "3,5", "12 %"],
            [" ", " ", " ", " ", " "],
            ["Ignoré", "NBL", "99", "99", "99"],
        ])
        let report = try GoldReportParser.parse(grid: grid, fileName: "t.xlsx", filePath: "/t.xlsx")
        XCTAssertEqual(report.product, "Mac")
        XCTAssertEqual(report.dimension, "Store")
        XCTAssertEqual(report.members, ["R001 - Un", "R002 - Deux"])
        XCTAssertEqual(report.value(member: "R001 - Un", metric: "LY", period: .week(fiscalYear: 2026, quarter: 1, week: 1)), 8)
        XCTAssertNil(report.value(member: "R001 - Un", metric: "LY", period: .week(fiscalYear: 2026, quarter: 1, week: 2)))
        XCTAssertEqual(report.value(member: "R002 - Deux", metric: "NBL", period: .week(fiscalYear: 2026, quarter: 1, week: 1)), 1200)
        XCTAssertEqual(report.value(member: "R002 - Deux", metric: "NBL", period: .week(fiscalYear: 2026, quarter: 1, week: 2)), 3.5)
        XCTAssertEqual(report.value(member: "R002 - Deux", metric: "NBL", period: .quarter(fiscalYear: 2026, quarter: 1)), 0.12)
    }

    func testParseNumber() {
        XCTAssertEqual(GoldReportParser.parseNumber("448"), 448)
        XCTAssertEqual(GoldReportParser.parseNumber("-0.5"), -0.5)
        XCTAssertEqual(GoldReportParser.parseNumber("0,47"), 0.47)
        XCTAssertEqual(GoldReportParser.parseNumber("47 %"), 0.47)
        XCTAssertNil(GoldReportParser.parseNumber("-"))
        XCTAssertNil(GoldReportParser.parseNumber("n/a"))
        XCTAssertNil(GoldReportParser.parseNumber(nil))
        XCTAssertNil(GoldReportParser.parseNumber("abc"))
    }
}
