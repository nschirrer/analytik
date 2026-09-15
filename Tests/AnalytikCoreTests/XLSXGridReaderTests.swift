import XCTest
@testable import AnalytikCore

final class XLSXGridReaderTests: XCTestCase {
    func testReadsSubChannelSheetAsGrid() throws {
        let grids = try XLSXGridReader.readSheets(atPath: try Fixtures.url("gold-subchannel").path)
        XCTAssertEqual(grids.count, 1)
        let grid = try XCTUnwrap(grids.first)
        XCTAssertEqual(grid.name, "Sub-Channel")
        XCTAssertEqual(grid.cell(1, 0), "Product")
        XCTAssertEqual(grid.cell(1, 2), "iPhone")
        XCTAssertEqual(grid.cell(7, 0), "Type")
        XCTAssertTrue((grid.cell(7, 2) ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertEqual(grid.cell(7, 4), "REFURB")
        XCTAssertEqual(grid.cell(9, 0), "Sub-Channel")
        XCTAssertEqual(grid.cell(9, 2), "FY26Q3_W1")
        XCTAssertEqual(grid.cell(9, 15), "26'Q2")
        XCTAssertEqual(grid.cell(10, 0), "TOTAL")
        XCTAssertEqual(grid.cell(10, 1), "NBL")
        XCTAssertEqual(grid.cell(10, 2), "360")
        XCTAssertEqual(grid.cell(11, 2), "0.5")
        XCTAssertEqual(grid.cell(23, 2), "-")
        XCTAssertNil(grid.cell(200, 0))
        XCTAssertNil(grid.cell(0, 200))
    }

    func testReadsAllSheets() throws {
        let grids = try XLSXGridReader.readSheets(atPath: try Fixtures.url("gold-products").path)
        XCTAssertEqual(grids.map { $0.name }, ["Notes", "Product"])
    }

    func testInvalidFileThrows() {
        XCTAssertThrowsError(try XLSXGridReader.readSheets(atPath: "/nonexistent/file.xlsx"))
    }
}
