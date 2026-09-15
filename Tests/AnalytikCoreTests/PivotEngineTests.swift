import XCTest
@testable import AnalytikCore

final class PivotEngineTests: XCTestCase {
    func testWeeklyUnitsByMember() throws {
        let report = try Fixtures.subChannelReport()
        let table = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .nbl, series: .member, granularity: .week))
        XCTAssertEqual(table.seriesTitle, "Sub-Channel")
        XCTAssertEqual(table.columns.count, 13)
        XCTAssertEqual(table.columns.first, Fixtures.week(1))
        XCTAssertEqual(table.rows.map { $0.label }, report.members)
        let total = try XCTUnwrap(table.row(id: "TOTAL"))
        XCTAssertTrue(total.isTotal)
        XCTAssertEqual(total.value(for: Fixtures.week(1)), 360)
        XCTAssertEqual(total.total, 4595)
        let pos = try XCTUnwrap(table.row(id: "RP - Retail POS"))
        XCTAssertEqual(pos.total, 2939)
        XCTAssertFalse(pos.isTotal)
    }

    func testQuarterGranularity() throws {
        let report = try Fixtures.subChannelReport()
        let table = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .nbl, granularity: .quarter))
        XCTAssertEqual(table.columns, [.quarter(fiscalYear: 2026, quarter: 2), .quarter(fiscalYear: 2026, quarter: 3)])
        let total = try XCTUnwrap(table.row(id: "TOTAL"))
        XCTAssertEqual(total.value(for: .quarter(fiscalYear: 2026, quarter: 2)), 4262)
        XCTAssertEqual(total.value(for: .quarter(fiscalYear: 2026, quarter: 3)), 4595)
    }

    func testGrowthAndMixAreRecomputedFromSums() throws {
        let report = try Fixtures.subChannelReport()
        let growth = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .yoy))
        let mix = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .mix))
        var compared = 0
        for member in report.members {
            for period in report.periods(of: .week) {
                if let expected = report.value(member: member, metric: .yoy, period: period) {
                    let actual = try XCTUnwrap(growth.row(id: member)?.value(for: period), "y/y \(member) \(period.label)")
                    XCTAssertEqual(actual, expected, accuracy: 0.0051, "y/y \(member) \(period.label)")
                    compared += 1
                }
                if let expected = report.value(member: member, metric: .mix, period: period) {
                    let actual = try XCTUnwrap(mix.row(id: member)?.value(for: period), "Mix \(member) \(period.label)")
                    XCTAssertEqual(actual, expected, accuracy: 0.0051, "Mix \(member) \(period.label)")
                    compared += 1
                }
            }
        }
        XCTAssertGreaterThan(compared, 90)
        // Les membres n'ont pas de ligne LY : elle est estimée depuis y/y, et signalée.
        XCTAssertTrue(growth.usesDerivedLastYear)
        XCTAssertFalse(mix.usesDerivedLastYear)
        let ly = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .ly))
        XCTAssertEqual(try XCTUnwrap(ly.row(id: "TOTAL")?.value(for: Fixtures.week(1))), 240)
        XCTAssertEqual(try XCTUnwrap(ly.row(id: "RP - Retail POS")?.value(for: Fixtures.week(1))), 210.0 / 1.06, accuracy: 1e-9)
        XCTAssertNil(ly.row(id: "RK - RETAIL KIOSK")?.value(for: Fixtures.week(1)))
        // Le TOTAL représente 100 % du périmètre.
        XCTAssertEqual(try XCTUnwrap(mix.row(id: "TOTAL")?.value(for: Fixtures.week(1))), 1, accuracy: 1e-9)
        // Le total de ligne d'un ratio est recalculé sur les sommes : y/y du trimestre.
        let quarterGrowth = try XCTUnwrap(growth.row(id: "TOTAL")?.total)
        XCTAssertEqual(quarterGrowth, 4595.0 / 3513.0 - 1, accuracy: 1e-9)
    }

    func testFilters() throws {
        let report = try Fixtures.subChannelReport()
        let onlyW1 = PivotEngine.pivot(reports: [report], query: PivotQuery(periodIDs: [Fixtures.week(1).id]))
        XCTAssertEqual(onlyW1.columns, [Fixtures.week(1)])
        XCTAssertEqual(onlyW1.row(id: "TOTAL")?.total, 360)

        let noTotal = PivotEngine.pivot(reports: [report], query: PivotQuery(includeTotalMember: false))
        XCTAssertEqual(noTotal.rows.count, 4)
        XCTAssertNil(noTotal.row(id: "TOTAL"))

        let onlyWeb = PivotEngine.pivot(reports: [report], query: PivotQuery(seriesKeys: ["RW - RETAIL WEB"]))
        XCTAssertEqual(onlyWeb.rows.map { $0.id }, ["RW - RETAIL WEB"])

        let none = PivotEngine.pivot(reports: [report], query: PivotQuery(reportIDs: []))
        XCTAssertTrue(none.isEmpty)
    }

    func testMixWithoutTotalMemberUsesSumOfLeaves() throws {
        let report = try Fixtures.productsReport()
        let mix = PivotEngine.pivot(reports: [report], query: PivotQuery(metric: .mix))
        let w1 = Fixtures.week(1, q: 4)
        XCTAssertEqual(try XCTUnwrap(mix.row(id: "iPhone")?.value(for: w1)), 400.0 / 610.0, accuracy: 1e-9)
        XCTAssertEqual(mix.rows.count, 3)
    }

    func testProductSeriesAcrossReportsWithoutDoubleCounting() throws {
        let subChannel = try Fixtures.subChannelReport()
        let products = try Fixtures.productsReport()
        let table = PivotEngine.pivot(reports: [subChannel, products], query: PivotQuery(metric: .nbl, series: .product))
        XCTAssertEqual(table.seriesTitle, "Produit")
        XCTAssertEqual(table.rows.map { $0.id }, ["iPhone", "All"])
        XCTAssertEqual(table.columns.count, 17)
        let iphone = try XCTUnwrap(table.row(id: "iPhone"))
        XCTAssertEqual(iphone.value(for: Fixtures.week(1)), 360)           // membre TOTAL uniquement
        XCTAssertNil(iphone.value(for: Fixtures.week(1, q: 4)))             // période absente ⇒ nil
        let all = try XCTUnwrap(table.row(id: "All"))
        XCTAssertEqual(all.value(for: Fixtures.week(1, q: 4)), 610)          // somme des feuilles
        XCTAssertEqual(all.total, 1580 + 500 + 370)
        XCTAssertTrue(PivotEngine.hasMixedDimensions([subChannel, products]))
        XCTAssertFalse(PivotEngine.hasMixedDimensions([subChannel]))
    }

    func testAvailableSeriesAndPeriods() throws {
        let subChannel = try Fixtures.subChannelReport()
        let products = try Fixtures.productsReport()
        let stores = PivotEngine.availableSeries(reports: [subChannel, products], series: .store, includeTotalMember: true)
        XCTAssertEqual(stores.map { $0.id }, ["R000 - Exemple"])
        let files = PivotEngine.availableSeries(reports: [subChannel, products], series: .report, includeTotalMember: true)
        XCTAssertEqual(files.map { $0.label }, ["gold-subchannel.xlsx", "gold-products.xlsx"])
        let members = PivotEngine.availableSeries(reports: [subChannel], series: .member, includeTotalMember: false)
        XCTAssertEqual(members.count, 4)
        let quarters = PivotEngine.availablePeriods(reports: [subChannel, products], granularity: .quarter)
        XCTAssertEqual(quarters.map { $0.label }, ["FY26 Q2", "FY26 Q3", "FY26 Q4"])
    }
}
