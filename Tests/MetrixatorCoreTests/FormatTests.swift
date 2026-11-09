import XCTest
@testable import MetrixatorCore

final class FormatTests: XCTestCase {
    override func tearDown() { L10n.current = .fr }

    func testFrenchFormatting() {
        L10n.current = .fr
        XCTAssertEqual(NumberFormat.value(79_360), "79\u{202F}360")
        XCTAssertEqual(NumberFormat.value(112_364), "112,4\u{00A0}k")
        XCTAssertEqual(NumberFormat.value(1_254_000), "1,25\u{00A0}M")
        XCTAssertEqual(NumberFormat.value(32.45), "32,5")
        XCTAssertEqual(NumberFormat.value(2.4), "2,4")
        XCTAssertEqual(NumberFormat.value(-1500), "−1\u{202F}500")
        XCTAssertEqual(NumberFormat.value(nil), "—")
        XCTAssertEqual(NumberFormat.value(1_254_000, compact: false), "1\u{202F}254\u{202F}000")
        XCTAssertEqual(NumberFormat.valueWithUnit(12_345, unit: "€"), "12\u{202F}345\u{00A0}€")
        XCTAssertEqual(NumberFormat.change(4.21, inPoints: false), "+4,2\u{00A0}%")
        XCTAssertEqual(NumberFormat.change(-1.25, inPoints: true), "−1,3\u{00A0}pt")
        XCTAssertEqual(NumberFormat.change(0.01, inPoints: false), "0\u{00A0}%")
        XCTAssertEqual(NumberFormat.change(157.1, inPoints: false), "+157\u{00A0}%")
    }

    func testEnglishFormatting() {
        L10n.current = .en
        XCTAssertEqual(NumberFormat.value(79_360), "79,360")
        XCTAssertEqual(NumberFormat.value(112_364), "112.4\u{00A0}k")
        XCTAssertEqual(NumberFormat.valueWithUnit(12_345, unit: "€"), "€12,345")
        XCTAssertEqual(NumberFormat.valueWithUnit(32.5, unit: "%"), "32.5%")
        XCTAssertEqual(NumberFormat.change(4.21, inPoints: false), "+4.2%")
        XCTAssertEqual(NumberFormat.change(2, inPoints: true), "+2 pts")
    }

    func testParsing() {
        L10n.current = .fr
        XCTAssertEqual(NumberFormat.parse("12345"), 12345)
        XCTAssertEqual(NumberFormat.parse("12 345,6"), 12345.6)
        XCTAssertEqual(NumberFormat.parse("12\u{202F}345,6 €"), 12345.6)
        XCTAssertEqual(NumberFormat.parse("12,345.6"), 12345.6)
        XCTAssertEqual(NumberFormat.parse("12.345,6"), 12345.6)
        XCTAssertEqual(NumberFormat.parse("1.234.567"), 1234567)
        XCTAssertEqual(NumberFormat.parse("12,5"), 12.5)
        XCTAssertEqual(NumberFormat.parse("12,345"), 12.345) // virgule décimale en français
        XCTAssertEqual(NumberFormat.parse("-3,2 %"), -3.2)
        XCTAssertEqual(NumberFormat.parse("−3,2"), -3.2)
        XCTAssertEqual(NumberFormat.parse("+4.5%"), 4.5)
        XCTAssertEqual(NumberFormat.parse(",5"), 0.5)
        XCTAssertEqual(NumberFormat.parse("1,5 pt"), 1.5)

        for bad in ["", "  ", "abc", "12a", "1,2,3", "12..5", "1-2", "€", "5.", "++5", "1 2,3,4"] {
            XCTAssertNil(NumberFormat.parse(bad), "« \(bad) » devrait être refusé")
        }

        L10n.current = .en
        XCTAssertEqual(NumberFormat.parse("12,345"), 12345) // séparateur de milliers en anglais
        XCTAssertEqual(NumberFormat.parse("12,5"), 12.5)
    }

    func testLabels() {
        L10n.current = .fr
        let cal = FiscalCalendar.standard
        let w = cal.previousWeek(today: Day(2026, 11, 9))
        XCTAssertEqual(L10n.weekLong(w), "S6 FY27 · 1–7 nov.")
        let w2 = cal.week(containing: Day(2026, 9, 28))
        XCTAssertEqual(L10n.range(w2.start, w2.end), "27 sept. – 3 oct.")
        L10n.current = .en
        XCTAssertEqual(L10n.weekLong(w), "W6 FY27 · Nov 1–7")
    }
}
