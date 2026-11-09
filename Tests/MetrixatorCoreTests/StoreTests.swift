import XCTest
@testable import MetrixatorCore

final class StoreTests: XCTestCase {
    let today = Day(2026, 11, 9) // lundi ; PWK = S6 FY27 (1–7 nov.)
    var dir: URL!

    override func setUpWithError() throws {
        L10n.current = .fr
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("metrixator-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func makeStore(seed: Bool = false) -> MetricStore {
        let d = today
        return MetricStore(fileURL: dir.appendingPathComponent("data.json"), seedWithSampleData: seed, today: { d })
    }

    // MARK: Critère 1 — ajouter des chiffres et les retrouver sur le tableau de synthèse

    func testCritere1_addMetricAndValuesAppearOnDashboard() throws {
        let store = makeStore()
        XCTAssertTrue(store.metrics.isEmpty)
        let m = try store.addMetric(Metric(name: "Chiffre d'affaires", kind: .currency, display: .line, color: .purple))
        try store.addEntry(metricID: m.id, week: Day(2026, 11, 3), value: 12_500) // n'importe quel jour de la semaine
        try store.addEntry(metricID: m.id, week: Day(2026, 10, 25), value: 10_000)

        let saved = store.metric(m.id)!
        XCTAssertEqual(saved.entries.map(\.week), [Day(2026, 10, 25), Day(2026, 11, 1)], "valeurs triées et recalées sur le début de semaine")
        XCTAssertTrue(saved.showOnDashboard)

        // Ce que la tuile du tableau de synthèse affiche en PWK.
        let tile = Analytics.summary(of: saved, period: .pwk, reference: store.previousWeek, calendar: store.calendar)
        XCTAssertEqual(tile.value, 12_500)
        XCTAssertEqual(NumberFormat.valueWithUnit(tile.value, unit: saved.unit), "12\u{202F}500\u{00A0}€")
        XCTAssertEqual(tile.change!, 25, accuracy: 1e-9)
    }

    // MARK: Critère 2 — ajouter une donnée met à jour la progression

    func testCritere2_addingValueUpdatesProgression() throws {
        let store = makeStore()
        let m = try store.addMetric(Metric(name: "Ventes", kind: .units))
        let cal = store.calendar
        let pwk = store.previousWeek
        let ly = cal.sameWeekLastYear(pwk)!

        try store.addEntry(metricID: m.id, week: pwk.start, value: 230, manualYoY: 15)
        var s = Analytics.summary(of: store.metric(m.id)!, period: .pwk, reference: pwk, calendar: cal)
        XCTAssertEqual(s.yoy!, 15, accuracy: 1e-9)
        XCTAssertEqual(s.yoySource, .manual)

        // L'ajout de la même semaine N-1 fait passer au calcul automatique.
        try store.addEntry(metricID: m.id, week: ly.start, value: 184)
        s = Analytics.summary(of: store.metric(m.id)!, period: .pwk, reference: pwk, calendar: cal)
        XCTAssertEqual(s.yoy!, 25, accuracy: 1e-9) // 230 / 184 − 1
        XCTAssertEqual(s.yoySource, .computed)

        // QTD : ajout d'une semaine → cumul et progression recalculés.
        try store.addEntry(metricID: m.id, week: cal.week(offset: -1, from: pwk).start, value: 200, manualYoY: 0)
        let q = Analytics.summary(of: store.metric(m.id)!, period: .qtd, reference: pwk, calendar: cal)
        XCTAssertEqual(q.value, 430)
        XCTAssertEqual(q.yoy!, (430.0 / 384 - 1) * 100, accuracy: 1e-9)
        XCTAssertEqual(q.yoySource, .mixed)
    }

    // MARK: Critère 3 — plusieurs formats d'affichage par résultat

    func testCritere3_eachMetricCanUseEveryDisplayStyle() throws {
        let store = makeStore()
        var m = try store.addMetric(Metric(name: "NPS", kind: .score))
        for style in DisplayStyle.allCases {
            m.display = style
            m.color = MetricColor.allCases[DisplayStyle.allCases.firstIndex(of: style)!]
            try store.updateMetric(m)
            XCTAssertEqual(store.metric(m.id)?.display, style)
            XCTAssertEqual(makeStore().metric(m.id)?.display, style, "format conservé après relance")
        }
        XCTAssertEqual(DisplayStyle.allCases.count, 5)
    }

    // MARK: Critère 4 — les données sont sauvegardées

    func testCritere4_dataPersistsAcrossLaunches() throws {
        let store = makeStore()
        let m = try store.addMetric(Metric(name: "Panier moyen", details: "TTC", kind: .currency, aggregation: .average,
                                           higherIsBetter: true, display: .bars, color: .orange))
        try store.addEntry(metricID: m.id, week: Day(2026, 11, 1), value: 182.5, manualYoY: -2.5)
        var settings = store.settings
        settings.period = .qtd
        settings.calendar = FiscalCalendar(yearEndMonth: 9, firstWeekday: 1)
        store.updateSettings(settings)

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.data, store.data)
        XCTAssertEqual(reloaded.settings.period, .qtd)
        XCTAssertEqual(reloaded.metric(m.id)?.entries.first?.manualYoY, -2.5)

        #if os(macOS) || os(Linux)
        let attrs = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent("data.json").path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600, "fichier lisible par l'utilisateur seulement")
        #endif
    }

    func testFirstLaunchSeedsSampleData() {
        let store = makeStore(seed: true)
        XCTAssertEqual(store.metrics.count, 22)
        XCTAssertEqual(makeStore(seed: true).data, store.data, "les données d'exemple ne sont créées qu'une fois")
    }

    func testCorruptFileIsSetAsideAndAppStartsEmpty() throws {
        try Data("{ pas du json".utf8).write(to: dir.appendingPathComponent("data.json"))
        let store = makeStore(seed: true)
        XCTAssertTrue(store.metrics.isEmpty)
        XCTAssertNotNil(store.loadIssue)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("metrixator-illisible-") })
    }

    // MARK: Cas limites

    func testDuplicateNameIsBlocked() throws {
        let store = makeStore()
        try store.addMetric(Metric(name: "Chiffre d'affaires"))
        XCTAssertThrowsError(try store.addMetric(Metric(name: "  chiffre D'AFFAIRES "))) {
            XCTAssertEqual($0 as? MetrixError, .duplicateName("chiffre D'AFFAIRES"))
        }
        XCTAssertThrowsError(try store.addMetric(Metric(name: "Chiffre  d’affaires".replacingOccurrences(of: "’", with: "'"))))
        XCTAssertThrowsError(try store.addMetric(Metric(name: "   "))) { XCTAssertEqual($0 as? MetrixError, .emptyName) }
        XCTAssertEqual(store.metrics.count, 1)
    }

    func testDuplicateWeekIsBlocked() throws {
        let store = makeStore()
        let m = try store.addMetric(Metric(name: "Ventes"))
        try store.addEntry(metricID: m.id, week: Day(2026, 11, 1), value: 10)
        XCTAssertThrowsError(try store.addEntry(metricID: m.id, week: Day(2026, 11, 6), value: 99)) {
            XCTAssertEqual($0 as? MetrixError, .duplicateEntry(Day(2026, 11, 1)))
        }
        XCTAssertEqual(store.metric(m.id)?.entries.count, 1)
        XCTAssertEqual(store.metric(m.id)?.entries.first?.value, 10)
    }

    func testIncompleteWeekAndInvalidYoYAreRejected() throws {
        let store = makeStore()
        let m = try store.addMetric(Metric(name: "Ventes"))
        XCTAssertThrowsError(try store.addEntry(metricID: m.id, week: Day(2026, 11, 8), value: 1)) {
            XCTAssertEqual($0 as? MetrixError, .incompleteWeek)
        }
        XCTAssertThrowsError(try store.addEntry(metricID: m.id, week: Day(2026, 11, 1), value: 1, manualYoY: -100)) {
            XCTAssertEqual($0 as? MetrixError, .invalidYoY)
        }
        XCTAssertThrowsError(try store.addEntry(metricID: m.id, week: Day(2026, 11, 1), value: .nan))
    }

    func testEntryValidatorFlagsEachField() throws {
        let m = Metric(name: "Ventes", entries: [Entry(week: Day(2026, 10, 25), value: 5)])
        let cal = FiscalCalendar.standard
        let pwk = cal.previousWeek(today: today)

        let ok = Validator.validateEntry(valueText: "1 234,5", yoyText: "+3,2 %", metric: m, week: pwk, today: today)
        XCTAssertTrue(ok.isValid)
        XCTAssertEqual(ok.value, 1234.5)
        XCTAssertEqual(ok.manualYoY, 3.2)

        let bad = Validator.validateEntry(valueText: "12abc", yoyText: "-150", metric: m, week: pwk, today: today)
        XCTAssertEqual(bad.valueError, .invalidValue)
        XCTAssertEqual(bad.yoyError, .invalidYoY)
        XCTAssertFalse(bad.isValid)

        let dup = Validator.validateEntry(valueText: "3", yoyText: "", metric: m, week: cal.week(containing: Day(2026, 10, 25)), today: today)
        XCTAssertEqual(dup.weekError, .duplicateEntry(Day(2026, 10, 25)))
        let editing = Validator.validateEntry(valueText: "3", yoyText: "", metric: m, week: cal.week(containing: Day(2026, 10, 25)),
                                              today: today, isEditingExisting: true)
        XCTAssertTrue(editing.isValid)

        let future = Validator.validateEntry(valueText: "3", yoyText: "", metric: m, week: cal.week(containing: today), today: today)
        XCTAssertEqual(future.weekError, .incompleteWeek)

        let pts = Validator.validateEntry(valueText: "30", yoyText: "-150", metric: Metric(name: "T", kind: .percent), week: pwk, today: today)
        XCTAssertNil(pts.yoyError, "en points, une baisse de plus de 100 est possible")
    }

    func testDeletionCanBeUndone() throws {
        let store = makeStore()
        let a = try store.addMetric(Metric(name: "A"))
        try store.addMetric(Metric(name: "B"))
        try store.addEntry(metricID: a.id, week: Day(2026, 11, 1), value: 7)

        store.deleteEntry(metricID: a.id, week: Day(2026, 11, 1))
        XCTAssertTrue(store.metric(a.id)!.entries.isEmpty)
        store.deleteMetric(a.id)
        XCTAssertNil(store.metric(a.id))
        XCTAssertTrue(store.canUndo)
        XCTAssertEqual(store.undoLabel, "Suppression de « A »")

        store.undo()
        XCTAssertEqual(store.metrics.map(\.name), ["A", "B"], "le résultat revient à sa place")
        XCTAssertEqual(makeStore().metrics.map(\.name), ["A", "B"], "l'annulation est enregistrée")
        store.undo()
        XCTAssertEqual(store.metric(a.id)?.entries.first?.value, 7)
        XCTAssertFalse(store.canUndo)

        store.eraseAll()
        XCTAssertTrue(store.metrics.isEmpty)
        store.undo()
        XCTAssertEqual(store.metrics.count, 2)
    }

    func testUpdateMetricKeepsEntriesAndChecksName() throws {
        let store = makeStore()
        var a = try store.addMetric(Metric(name: "A"))
        try store.addMetric(Metric(name: "B"))
        try store.addEntry(metricID: a.id, week: Day(2026, 11, 1), value: 7)
        a.name = "A renommé"
        a.entries = []
        try store.updateMetric(a)
        XCTAssertEqual(store.metric(a.id)?.name, "A renommé")
        XCTAssertEqual(store.metric(a.id)?.entries.count, 1)
        a.name = "b"
        XCTAssertThrowsError(try store.updateMetric(a))
    }

    func testMoveMetrics() throws {
        let store = makeStore()
        for n in ["A", "B", "C", "D"] { try store.addMetric(Metric(name: n)) }
        store.moveMetrics(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(store.metrics.map(\.name), ["B", "C", "A", "D"])
        store.moveMetrics(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        XCTAssertEqual(store.metrics.map(\.name), ["D", "B", "C", "A"])
        store.moveMetrics(fromOffsets: IndexSet([0, 1]), toOffset: 4)
        XCTAssertEqual(store.metrics.map(\.name), ["C", "A", "D", "B"])
    }

    func testChangingWeekStartRealignsEntries() throws {
        let store = makeStore()
        let m = try store.addMetric(Metric(name: "A"))
        try store.addEntry(metricID: m.id, week: Day(2026, 11, 1), value: 1) // dimanche
        var s = store.settings
        s.calendar = FiscalCalendar(yearEndMonth: 9, firstWeekday: 2) // lundi
        store.updateSettings(s)
        XCTAssertEqual(store.metric(m.id)?.entries.first?.week, Day(2026, 10, 26))
        XCTAssertEqual(store.metric(m.id)?.entries.first?.week.weekday, 2)
    }

    func testEditEntry() throws {
        let store = makeStore()
        let m = try store.addMetric(Metric(name: "A"))
        try store.addEntry(metricID: m.id, week: Day(2026, 11, 1), value: 1)
        try store.updateEntry(metricID: m.id, week: Day(2026, 11, 1), value: 2, manualYoY: 5)
        XCTAssertEqual(store.metric(m.id)?.entries.first, Entry(week: Day(2026, 11, 1), value: 2, manualYoY: 5))
        XCTAssertThrowsError(try store.updateEntry(metricID: m.id, week: Day(2026, 10, 1), value: 2, manualYoY: nil))
    }
}
