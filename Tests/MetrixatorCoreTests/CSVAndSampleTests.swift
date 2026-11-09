import XCTest
@testable import MetrixatorCore

final class CSVTests: XCTestCase {
    let today = Day(2026, 11, 9)
    let cal = FiscalCalendar.standard

    override func setUp() { L10n.current = .fr }

    func testParserHandlesQuotes() {
        let rows = CSV.parse("a;\"b;c\";\"d \"\"e\"\"\"\r\n1;2;3\n", separator: ";")
        XCTAssertEqual(rows, [["a", "b;c", "d \"e\""], ["1", "2", "3"]])
    }

    func testExportThenImportRoundTrip() {
        let original = SampleData.make(today: today).metrics
        let text = CSV.export(original, calendar: cal)
        XCTAssertTrue(text.hasPrefix("resultat;semaine;semaine_fiscale;valeur;yoy_saisi;nature;unite;agregation\n"))
        XCTAssertTrue(text.contains("Chiffre d'affaires total;2026-11-01;W6 FY27;"))

        let (imported, report) = CSV.merge(text, into: [], calendar: cal, today: today)
        XCTAssertEqual(report.errors.count, 0)
        XCTAssertEqual(report.createdMetrics, 21, "le résultat sans données n'a aucune ligne")
        XCTAssertEqual(report.addedEntries, original.reduce(0) { $0 + $1.entries.count })
        for m in original where !m.entries.isEmpty {
            let i = imported.first { $0.name == m.name }!
            XCTAssertEqual(i.entries, m.entries)
            XCTAssertEqual(i.kind, m.kind)
            XCTAssertEqual(i.unit, m.unit)
            XCTAssertEqual(i.aggregation, m.aggregation)
        }

        // Réimporter le même fichier : tout est bloqué comme doublon.
        let (again, report2) = CSV.merge(text, into: imported, calendar: cal, today: today)
        XCTAssertEqual(again, imported)
        XCTAssertEqual(report2.addedEntries, 0)
        XCTAssertEqual(report2.duplicates.count, report.addedEntries)
    }

    func testImportFrenchExcelStyleAndErrors() {
        let csv = """
        Résultat;Semaine;Valeur;YoY
        Ventes;2026-11-03;1 234,5;+4,5 %
        Ventes;2026-11-02;99;
        Ventes;2026-13-01;5;
        Ventes;2026-10-25;abc;
        ;2026-10-25;5;
        Ventes;2026-11-09;5;
        Ventes;2026-10-18;5;-120
        """
        let (metrics, report) = CSV.merge(csv, into: [], calendar: cal, today: today)
        XCTAssertEqual(report.createdMetrics, 1)
        XCTAssertEqual(report.addedEntries, 1)
        XCTAssertEqual(report.duplicates, [3])
        XCTAssertEqual(report.errors.map(\.line), [4, 5, 6, 7, 8])
        XCTAssertEqual(metrics.first?.entries, [Entry(week: Day(2026, 11, 1), value: 1234.5, manualYoY: 4.5)])
    }

    func testImportCommaSeparatedIntoExistingMetric() {
        let existing = Metric(name: "Chiffre d'affaires", kind: .currency)
        let csv = "metric,week,value\n\"CHIFFRE D'AFFAIRES\",2026-11-01,\"12,345\"\n"
        let (metrics, report) = CSV.merge(csv, into: [existing], calendar: cal, today: today)
        XCTAssertEqual(report.createdMetrics, 0)
        XCTAssertEqual(metrics.count, 1)
        XCTAssertEqual(metrics[0].entries.first?.value, 12.345) // virgule décimale (interface en français)
    }

    func testMissingColumns() {
        let (_, report) = CSV.merge("a;b\n1;2\n", into: [], calendar: cal, today: today)
        XCTAssertEqual(report.errors.first?.line, 1)
    }

    func testStoreImportIsUndoable() throws {
        let store = MetricStore(fileURL: nil, seedWithSampleData: false, today: { Day(2026, 11, 9) })
        let report = store.importCSV("resultat;semaine;valeur\nA;2026-11-01;3\n")
        XCTAssertEqual(report.summary, "1 valeur(s) importée(s) · 1 résultat(s) créé(s)")
        XCTAssertEqual(store.metrics.count, 1)
        store.undo()
        XCTAssertTrue(store.metrics.isEmpty)
    }
}

final class SampleDataTests: XCTestCase {
    func testSampleDataShape() {
        L10n.current = .fr
        let today = Day(2026, 11, 9)
        let data = SampleData.make(today: today)
        let cal = data.settings.calendar
        let pwk = cal.previousWeek(today: today)
        XCTAssertEqual(data.metrics.count, 22)
        XCTAssertEqual(Set(data.metrics.map(\.normalizedName)).count, 22, "pas de doublon")
        XCTAssertEqual(Set(data.metrics.map(\.display)), Set(DisplayStyle.allCases), "tous les formats sont illustrés")
        XCTAssertGreaterThanOrEqual(Set(data.metrics.map(\.color)).count, 8)

        let empty = data.metrics.filter { $0.entries.isEmpty }
        XCTAssertEqual(empty.count, 1, "un résultat vide pour illustrer l'affichage vide")
        let missingPWK = data.metrics.filter { !$0.entries.isEmpty && $0.entry(for: pwk.start) == nil }
        XCTAssertEqual(missingPWK.count, 1, "une valeur de la semaine reste à saisir")

        for m in data.metrics where !m.entries.isEmpty {
            XCTAssertEqual(m.entries.first?.week, cal.week(fiscalYear: pwk.fiscalYear - 1, index: 1)?.start)
            XCTAssertTrue(m.entries.allSatisfy { $0.week < today })
            XCTAssertTrue(m.entries.allSatisfy { $0.value.isFinite })
            // Y/Y : calculé pour l'exercice en cours, saisi pour l'exercice précédent.
            let s = Analytics.summary(of: m, period: .ytd, reference: pwk, calendar: cal)
            if m.entry(for: pwk.start) != nil { XCTAssertEqual(s.yoySource, .computed, m.name) }
            let old = Analytics.summary(of: m, period: .ytd, reference: cal.week(fiscalYear: pwk.fiscalYear - 1, index: 52)!, calendar: cal)
            XCTAssertEqual(old.yoySource, .manual, m.name)
        }
        XCTAssertEqual(SampleData.make(today: today), data, "génération déterministe")
    }
}
