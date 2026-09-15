import AppKit
import Foundation
import Observation
import AnalytikCore

enum ViewMode: String, CaseIterable, Hashable {
    case table
    case chart
    case comparison

    var title: String {
        switch self {
        case .table: return "Tableau"
        case .chart: return "Graphique"
        case .comparison: return "Comparaison"
        }
    }
}

enum ChartKind: String, CaseIterable, Hashable {
    case bar
    case line

    var title: String {
        switch self {
        case .bar: return "Barres"
        case .line: return "Courbes"
        }
    }
}

enum ComparisonMode: String, CaseIterable, Hashable {
    case periods
    case series
    case lastYear

    var title: String {
        switch self {
        case .periods: return "Deux périodes"
        case .series: return "Deux lignes"
        case .lastYear: return "Année précédente"
        }
    }
}

struct ComparisonOption: Identifiable, Hashable {
    let id: String
    let label: String
}

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id: UUID
    var role: Role
    var text: String
    var note: String?

    init(id: UUID = UUID(), role: Role, text: String, note: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.note = note
    }
}

@MainActor
@Observable
final class AppModel {
    // MARK: Données

    var reports: [Report] = []
    /// Rapports inclus dans l'analyse.
    var selectedReportIDs: Set<UUID> = []
    var importErrors: [String] = []
    var isImporting = false

    // MARK: Analyse

    var metric: Metric = .nbl
    var series: SeriesDimension = .member
    var granularity: Granularity = .week
    var excludedPeriodIDs: Set<String> = []
    var excludedSeriesIDs: Set<String> = []
    var includeTotalMember = true
    var viewMode: ViewMode = .table
    var chartKind: ChartKind = .bar
    var chartIncludesTotal = false
    var comparisonMode: ComparisonMode = .periods
    var comparisonA = ""
    var comparisonB = ""

    // MARK: Claude

    var isClaudePanelShown = false
    var chat: [ChatMessage] = []
    var draft = ""
    var isStreaming = false
    var chatError: String?
    var apiKey = ""
    var claudeModel = ClaudeConfig.defaultModel
    var lastCacheRead = 0
    var servedBy: String?

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private let client = ClaudeClient()
    @ObservationIgnored private var datasetCache: (key: String, text: String)?
    @ObservationIgnored private var didBootstrap = false

    private enum Keys {
        static let model = "claudeModel"
        static let paths = "importedFilePaths"
    }

    static let suggestedQuestions = [
        "Quel sous-canal progresse le plus en y/y sur le trimestre ?",
        "Résume les ventes semaine par semaine et signale les semaines atypiques.",
        "Compare le mix des canaux entre le début et la fin de la période.",
    ]

    init() {
        claudeModel = UserDefaults.standard.string(forKey: Keys.model) ?? ClaudeConfig.defaultModel
        apiKey = (try? KeychainStore.read()) ?? ""
    }

    /// Recharge les fichiers de la session précédente (appelé à l'apparition de la fenêtre).
    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        let paths = UserDefaults.standard.stringArray(forKey: Keys.paths) ?? []
        let urls = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        importFiles(urls)
    }

    // MARK: Sélection et requête

    var selectedReports: [Report] {
        reports.filter { selectedReportIDs.contains($0.id) }
    }

    var availablePeriods: [Period] {
        PivotEngine.availablePeriods(reports: selectedReports, granularity: granularity)
    }

    var availableSeries: [SeriesOption] {
        PivotEngine.availableSeries(reports: selectedReports, series: series, includeTotalMember: includeTotalMember)
    }

    var memberDimensionTitle: String {
        PivotEngine.seriesTitle(reports: selectedReports, series: .member)
    }

    var hasMixedDimensions: Bool {
        PivotEngine.hasMixedDimensions(selectedReports)
    }

    var query: PivotQuery {
        let periodIDs: Set<String>? = excludedPeriodIDs.isEmpty
            ? nil
            : Set(availablePeriods.map { $0.id }).subtracting(excludedPeriodIDs)
        let seriesKeys: Set<String>? = excludedSeriesIDs.isEmpty
            ? nil
            : Set(availableSeries.map { $0.id }).subtracting(excludedSeriesIDs)
        return PivotQuery(
            metric: metric,
            series: series,
            granularity: granularity,
            reportIDs: selectedReportIDs,
            periodIDs: periodIDs,
            seriesKeys: seriesKeys,
            includeTotalMember: includeTotalMember
        )
    }

    var pivotTable: PivotTable {
        PivotEngine.pivot(reports: reports, query: query)
    }

    func isPeriodShown(_ id: String) -> Bool {
        !excludedPeriodIDs.contains(id)
    }

    func setPeriod(_ id: String, shown: Bool) {
        if shown { excludedPeriodIDs.remove(id) } else { excludedPeriodIDs.insert(id) }
    }

    func isSeriesShown(_ id: String) -> Bool {
        !excludedSeriesIDs.contains(id)
    }

    func setSeries(_ id: String, shown: Bool) {
        if shown { excludedSeriesIDs.remove(id) } else { excludedSeriesIDs.insert(id) }
    }

    func isReportIncluded(_ id: UUID) -> Bool {
        selectedReportIDs.contains(id)
    }

    func setReport(_ id: UUID, included: Bool) {
        if included { selectedReportIDs.insert(id) } else { selectedReportIDs.remove(id) }
    }

    // MARK: Comparaison

    var comparisonOptions: [ComparisonOption] {
        switch comparisonMode {
        case .periods: return pivotTable.columns.map { ComparisonOption(id: $0.id, label: $0.label) }
        case .series: return pivotTable.rows.map { ComparisonOption(id: $0.id, label: $0.label) }
        case .lastYear: return []
        }
    }

    var resolvedComparisonA: String {
        let options = comparisonOptions
        if options.contains(where: { $0.id == comparisonA }) { return comparisonA }
        return options.first?.id ?? ""
    }

    var resolvedComparisonB: String {
        let options = comparisonOptions
        let a = resolvedComparisonA
        if comparisonB != a, options.contains(where: { $0.id == comparisonB }) { return comparisonB }
        return options.first(where: { $0.id != a })?.id ?? a
    }

    var comparisonTable: ComparisonTable {
        switch comparisonMode {
        case .periods: return ComparisonEngine.comparePeriods(pivotTable, a: resolvedComparisonA, b: resolvedComparisonB)
        case .series: return ComparisonEngine.compareSeries(pivotTable, a: resolvedComparisonA, b: resolvedComparisonB)
        case .lastYear: return ComparisonEngine.currentVsLastYear(reports: reports, query: query)
        }
    }

    var statusText: String {
        let table = pivotTable
        let reportCount = selectedReports.count
        let columns = table.columns.count
        let unit = granularity == .week ? "semaine" : "trimestre"
        var parts = [
            "\(reportCount) rapport\(reportCount > 1 ? "s" : "")",
            "\(columns) \(unit)\(columns > 1 ? "s" : "")",
            "\(table.rows.count) ligne\(table.rows.count > 1 ? "s" : "")",
        ]
        if table.usesDerivedLastYear {
            parts.append("LY estimé depuis y/y pour les lignes sans LY")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Import et retrait

    var showsImportErrors: Bool {
        get { !importErrors.isEmpty }
        set { if !newValue { importErrors = [] } }
    }

    func importFromPanel() {
        importFiles(FilePanels.chooseWorkbooks())
    }

    func importFiles(_ urls: [URL]) {
        let targets = urls.filter { $0.pathExtension.lowercased() == "xlsx" }
        guard !targets.isEmpty else { return }
        isImporting = true
        Task { [weak self] in
            var imported: [Report] = []
            var errors: [String] = []
            for url in targets {
                let accessing = url.startAccessingSecurityScopedResource()
                do {
                    imported.append(contentsOf: try await AppModel.parse(url))
                } catch {
                    errors.append("\(url.lastPathComponent) : \(error.localizedDescription)")
                }
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            guard let self = self else { return }
            self.add(imported)
            self.importErrors = errors
            self.isImporting = false
        }
    }

    nonisolated private static func parse(_ url: URL) async throws -> [Report] {
        try GoldReportParser.parseAllSheets(fileURL: url)
    }

    private func add(_ newReports: [Report]) {
        for report in newReports {
            reports.removeAll { $0.filePath == report.filePath && $0.sheetName == report.sheetName }
            reports.append(report)
            selectedReportIDs.insert(report.id)
        }
        savePaths()
    }

    func removeReports(_ ids: Set<UUID>) {
        reports.removeAll { ids.contains($0.id) }
        selectedReportIDs.subtract(ids)
        savePaths()
    }

    private func savePaths() {
        var paths: [String] = []
        for report in reports where !paths.contains(report.filePath) {
            paths.append(report.filePath)
        }
        UserDefaults.standard.set(paths, forKey: Keys.paths)
    }

    // MARK: Export

    func exportCSV() {
        let table = pivotTable
        guard !table.isEmpty else { return }
        let slug = metric.rawValue.replacingOccurrences(of: "/", with: "-").lowercased()
        guard let url = FilePanels.chooseCSVDestination(suggestedName: "analytik-\(slug).csv") else { return }
        do {
            try CSVExporter.csv(table).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            importErrors = ["Export CSV impossible : \(error.localizedDescription)"]
        }
    }

    // MARK: Claude

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try KeychainStore.save(trimmed)
        apiKey = trimmed
    }

    func deleteAPIKey() throws {
        try KeychainStore.delete()
        apiKey = ""
    }

    func setClaudeModel(_ model: String) {
        claudeModel = model
        UserDefaults.standard.set(model, forKey: Keys.model)
    }

    func testConnection() async throws -> String {
        try await client.testConnection(config: ClaudeConfig(apiKey: apiKey, model: claudeModel))
    }

    /// Données envoyées à Claude : les rapports cochés, sérialisés une seule fois par sélection.
    func datasetText() -> String {
        let selected = selectedReports
        let key = selected.map { $0.id.uuidString }.sorted().joined(separator: ",")
        if let cache = datasetCache, cache.key == key { return cache.text }
        let text = DatasetSerializer.serialize(reports: selected)
        datasetCache = (key, text)
        return text
    }

    func ask(_ question: String) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        guard hasAPIKey else {
            chatError = ClaudeError.missingAPIKey.localizedDescription
            return
        }
        chatError = nil
        draft = ""
        chat.append(ChatMessage(role: .user, text: text))
        let turns = chat.map { ChatTurn(role: $0.role == .user ? "user" : "assistant", text: $0.text) }
        let answerID = UUID()
        chat.append(ChatMessage(id: answerID, role: .assistant, text: ""))
        isStreaming = true

        let config = ClaudeConfig(apiKey: apiKey, model: claudeModel)
        let dataset = datasetText()
        let client = self.client
        streamTask = Task { [weak self] in
            var refused = false
            do {
                for try await event in client.stream(config: config, rolePrompt: ClaudePrompts.role, dataset: dataset, turns: turns) {
                    guard let self = self else { return }
                    switch event {
                    case let .messageStart(model, cacheRead, _):
                        self.lastCacheRead = cacheRead
                        self.servedBy = model
                    case let .textDelta(delta):
                        self.append(delta, to: answerID)
                    case let .fallback(_, to):
                        self.servedBy = to
                        self.setNote("Réponse fournie par le modèle de repli \(to).", on: answerID)
                    case let .stop(reason, category):
                        if reason == "refusal" {
                            refused = true
                            let detail = category.map { " (catégorie : \($0))" } ?? ""
                            self.chatError = "Claude a refusé de répondre à cette demande\(detail)."
                        } else if reason == "max_tokens" {
                            self.setNote("Réponse tronquée : limite de longueur atteinte.", on: answerID)
                        }
                    case .done:
                        break
                    }
                }
            } catch is CancellationError {
                // Arrêt demandé par l'utilisateur.
            } catch {
                self?.chatError = error.localizedDescription
            }
            guard let self = self else { return }
            let answer = self.chat.first { $0.id == answerID }
            if refused || (answer?.text.isEmpty ?? true) {
                self.chat.removeAll { $0.id == answerID }
            }
            self.isStreaming = false
        }
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let last = chat.last, last.role == .assistant, last.text.isEmpty {
            chat.removeLast()
        }
    }

    func clearChat() {
        cancelStreaming()
        chat = []
        chatError = nil
        lastCacheRead = 0
        servedBy = nil
    }

    private func append(_ delta: String, to id: UUID) {
        guard let index = chat.firstIndex(where: { $0.id == id }) else { return }
        chat[index].text += delta
    }

    private func setNote(_ note: String, on id: UUID) {
        guard let index = chat.firstIndex(where: { $0.id == id }) else { return }
        chat[index].note = note
    }
}
