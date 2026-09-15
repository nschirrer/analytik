import XCTest
@testable import AnalytikCore

final class CSVExporterTests: XCTestCase {
    func testCSVLayout() throws {
        let report = try Fixtures.subChannelReport()
        let table = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .nbl, periodIDs: [Fixtures.week(1).id, Fixtures.week(2).id]))
        let csv = CSVExporter.csv(table)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"))
        let lines = String(csv.dropFirst()).components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines[0], "Sub-Channel;FY26 Q3 W1;FY26 Q3 W2;Total")
        XCTAssertEqual(lines[1], "TOTAL;360;330;690")
        XCTAssertEqual(lines.count, 6)
    }

    func testDecimalsAndEscaping() throws {
        let report = try Fixtures.subChannelReport()
        let table = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .yoy, periodIDs: [Fixtures.week(1).id]))
        let csv = CSVExporter.csv(table, includeBOM: false)
        XCTAssertTrue(csv.contains("TOTAL;0,5;0,5\r\n"))
        XCTAssertEqual(CSVExporter.escape("a;b", separator: ";"), "\"a;b\"")
        XCTAssertEqual(CSVExporter.escape("dit \"oui\"", separator: ";"), "\"dit \"\"oui\"\"\"")
        XCTAssertEqual(CSVExporter.format(nil, decimalSeparator: ","), "")
        XCTAssertEqual(CSVExporter.format(1234.5678, decimalSeparator: ","), "1234,5678")
    }

    func testNumberText() {
        XCTAssertEqual(NumberText.plain(448), "448")
        XCTAssertEqual(NumberText.plain(0.47), "0.47")
        XCTAssertEqual(NumberText.plain(-0.5), "-0.5")
        XCTAssertEqual(NumberText.plain(1.0 / 3.0), "0.3333")
        XCTAssertEqual(NumberText.plain(-1), "-1")
    }
}
