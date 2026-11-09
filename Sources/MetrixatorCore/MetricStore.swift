import Foundation
import Observation

/// Source de vérité de l'app : résultats suivis, valeurs hebdomadaires et réglages.
/// Chaque modification est enregistrée immédiatement dans un fichier JSON local (aucun cloud).
@Observable
public final class MetricStore {
    public private(set) var data: AppData
    /// Problème rencontré au chargement (fichier illisible…), à montrer une fois.
    public var loadIssue: String?
    /// Dernière erreur d'enregistrement.
    public private(set) var saveError: String?

    @ObservationIgnored public let fileURL: URL?
    @ObservationIgnored public var todayProvider: () -> Day

    private var undoStack: [(label: String, data: AppData)] = []
    private static let undoLimit = 30

    public var metrics: [Metric] { data.metrics }
    public var settings: AppSettings { data.settings }
    public var calendar: FiscalCalendar { data.settings.calendar }
    public var today: Day { todayProvider() }

    /// Dernière semaine terminée (PWK).
    public var previousWeek: FiscalWeek { calendar.previousWeek(today: today) }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var undoLabel: String? { undoStack.last?.label }

    // MARK: - Initialisation

    /// - Parameters:
    ///   - fileURL: fichier de données ; `nil` = en mémoire seulement (aperçus, tests).
    ///   - seedWithSampleData: remplit l'app avec les données d'exemple si le fichier n'existe pas encore.
    public init(fileURL: URL?, seedWithSampleData: Bool = true, today: @escaping () -> Day = { Day.today() }) {
        self.fileURL = fileURL
        self.todayProvider = today
        self.data = AppData()

        guard let fileURL else {
            if seedWithSampleData { data = SampleData.make(today: today()) }
            return
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let raw = try Data(contentsOf: fileURL)
                var decoded = try JSONDecoder().decode(AppData.self, from: raw)
                decoded.metrics = decoded.metrics.map { MetricStore.realigned($0, to: decoded.settings.calendar) }
                data = decoded
            } catch {
                let backup = fileURL.deletingLastPathComponent()
                    .appendingPathComponent("metrixator-illisible-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: fileURL, to: backup)
                loadIssue = L10n.tr("Le fichier de données était illisible. Il a été mis de côté (\(backup.lastPathComponent)) et l'app repart à vide.",
                                    "The data file could not be read. It was set aside (\(backup.lastPathComponent)) and the app starts empty.")
                save()
            }
        } else {
            if seedWithSampleData { data = SampleData.make(today: today()) }
            save()
        }
    }

    /// Emplacement par défaut : ~/Library/Application Support/Metrixator/metrixator.json
    /// (dossier local, non synchronisé par iCloud).
    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Metrixator", isDirectory: true).appendingPathComponent("metrixator.json")
    }

    // MARK: - Enregistrement

    public func save() {
        guard let fileURL else { return }
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
            // Données confidentielles : lisibles uniquement par l'utilisateur.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            saveError = nil
        } catch {
            saveError = L10n.tr("Enregistrement impossible : \(error.localizedDescription)", "Could not save: \(error.localizedDescription)")
        }
    }

    private func commit(_ newData: AppData, undoLabel: String? = nil) {
        if let undoLabel {
            undoStack.append((undoLabel, data))
            if undoStack.count > MetricStore.undoLimit { undoStack.removeFirst() }
        }
        data = newData
        save()
    }

    // MARK: - Annulation

    /// Annule la dernière suppression (ou opération de masse : import, effacement…).
    public func undo() {
        guard let last = undoStack.popLast() else { return }
        data = last.data
        save()
    }

    // MARK: - Résultats suivis

    public func metric(_ id: UUID) -> Metric? { data.metrics.first { $0.id == id } }

    @discardableResult
    public func addMetric(_ metric: Metric) throws -> Metric {
        if let error = Validator.validateName(metric.name, among: data.metrics) { throw error }
        var m = metric
        m.name = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
        var d = data
        d.metrics.append(m)
        commit(d)
        return m
    }

    /// Met à jour la définition d'un résultat (titre, nature, affichage…) sans toucher à ses valeurs.
    public func updateMetric(_ metric: Metric) throws {
        guard let i = data.metrics.firstIndex(where: { $0.id == metric.id }) else { throw MetrixError.metricNotFound }
        if let error = Validator.validateName(metric.name, among: data.metrics, excluding: metric.id) { throw error }
        var m = metric
        m.name = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
        m.entries = data.metrics[i].entries
        var d = data
        d.metrics[i] = m
        commit(d)
    }

    public func deleteMetric(_ id: UUID) {
        guard let i = data.metrics.firstIndex(where: { $0.id == id }) else { return }
        var d = data
        let removed = d.metrics.remove(at: i)
        commit(d, undoLabel: L10n.tr("Suppression de « \(removed.name) »", "Deletion of “\(removed.name)”"))
    }

    /// Déplace les résultats aux positions `offsets` vers la position `destination` (sémantique de `List.onMove`).
    public func moveMetrics(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var d = data
        let moving = offsets.sorted().map { d.metrics[$0] }
        let before = offsets.filter { $0 < destination }.count
        for i in offsets.sorted(by: >) { d.metrics.remove(at: i) }
        d.metrics.insert(contentsOf: moving, at: min(destination - before, d.metrics.count))
        commit(d)
    }

    // MARK: - Valeurs hebdomadaires

    /// Ajoute la valeur d'une semaine. Bloque les doublons et les semaines non terminées.
    public func addEntry(metricID: UUID, week day: Day, value: Double, manualYoY: Double? = nil) throws {
        guard let i = data.metrics.firstIndex(where: { $0.id == metricID }) else { throw MetrixError.metricNotFound }
        let week = calendar.week(containing: day)
        guard week.end < today else { throw MetrixError.incompleteWeek }
        guard value.isFinite else { throw MetrixError.invalidValue }
        if let y = manualYoY, !y.isFinite || (!data.metrics[i].kind.comparesInPoints && y <= -100) { throw MetrixError.invalidYoY }
        guard data.metrics[i].entry(for: week.start) == nil else { throw MetrixError.duplicateEntry(week.start) }
        var d = data
        d.metrics[i].entries.append(Entry(week: week.start, value: value, manualYoY: manualYoY))
        d.metrics[i].entries.sort { $0.week < $1.week }
        commit(d)
    }

    public func updateEntry(metricID: UUID, week day: Day, value: Double, manualYoY: Double?) throws {
        guard let i = data.metrics.firstIndex(where: { $0.id == metricID }) else { throw MetrixError.metricNotFound }
        let week = calendar.week(containing: day)
        guard let j = data.metrics[i].entries.firstIndex(where: { $0.week == week.start }) else { throw MetrixError.entryNotFound }
        guard value.isFinite else { throw MetrixError.invalidValue }
        if let y = manualYoY, !y.isFinite || (!data.metrics[i].kind.comparesInPoints && y <= -100) { throw MetrixError.invalidYoY }
        var d = data
        d.metrics[i].entries[j].value = value
        d.metrics[i].entries[j].manualYoY = manualYoY
        commit(d)
    }

    public func deleteEntry(metricID: UUID, week day: Day) {
        guard let i = data.metrics.firstIndex(where: { $0.id == metricID }) else { return }
        let week = calendar.week(containing: day)
        guard let j = data.metrics[i].entries.firstIndex(where: { $0.week == week.start }) else { return }
        var d = data
        d.metrics[i].entries.remove(at: j)
        commit(d, undoLabel: L10n.tr("Suppression de la valeur \(L10n.weekShort(week)) de « \(d.metrics[i].name) »",
                                     "Deletion of the \(L10n.weekShort(week)) value of “\(d.metrics[i].name)”"))
    }

    // MARK: - Réglages

    public func updateSettings(_ settings: AppSettings) {
        var d = data
        d.settings = settings
        if settings.calendar != data.settings.calendar {
            d.metrics = d.metrics.map { MetricStore.realigned($0, to: settings.calendar) }
        }
        commit(d)
    }

    public func setPeriod(_ period: PeriodKind) {
        var s = settings
        s.period = period
        updateSettings(s)
    }

    /// Recale chaque valeur sur le début de sa semaine (utile si le premier jour de semaine change).
    static func realigned(_ metric: Metric, to cal: FiscalCalendar) -> Metric {
        var m = metric
        var seen = Set<Day>()
        m.entries = metric.entries.compactMap { e in
            var e2 = e
            e2.week = cal.week(containing: e.week).start
            return seen.insert(e2.week).inserted ? e2 : nil
        }.sorted { $0.week < $1.week }
        return m
    }

    // MARK: - Opérations globales

    public func loadSampleData() {
        var d = SampleData.make(today: today, calendar: calendar)
        d.settings = data.settings
        commit(d, undoLabel: L10n.tr("Chargement des données d'exemple", "Loading sample data"))
    }

    public func eraseAll() {
        var d = AppData(settings: data.settings)
        d.metrics = []
        commit(d, undoLabel: L10n.tr("Effacement de toutes les données", "Erasing all data"))
    }

    // MARK: - CSV

    public func exportCSV() -> String { CSV.export(data.metrics, calendar: calendar) }

    /// Importe un CSV. Les doublons et les lignes incorrectes sont ignorés et listés dans le rapport.
    @discardableResult
    public func importCSV(_ text: String) -> CSV.ImportReport {
        let (newMetrics, report) = CSV.merge(text, into: data.metrics, calendar: calendar, today: today)
        if report.addedEntries > 0 || report.createdMetrics > 0 {
            var d = data
            d.metrics = newMetrics
            commit(d, undoLabel: L10n.tr("Import CSV", "CSV import"))
        }
        return report
    }
}
