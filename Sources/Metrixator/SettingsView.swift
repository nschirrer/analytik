#if os(macOS)
import AppKit
import MetrixatorCore
import SwiftUI
import UniformTypeIdentifiers

/// Réglages (⌘,) : langue, calendrier fiscal, données.
struct SettingsView: View {
    @Environment(MetricStore.self) private var store
    @State private var confirmSample = false
    @State private var confirmErase = false

    var body: some View {
        let settings = store.settings
        let cal = settings.calendar
        let currentFY = cal.fiscalYear(containing: store.today)
        Form {
            Section(tr("Langue", "Language")) {
                Picker(tr("Langue de l'interface", "Interface language"), selection: Binding(get: { settings.language }, set: { lang in
                    var s = store.settings
                    s.language = lang
                    L10n.apply(lang)
                    store.updateSettings(s)
                })) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                Text(tr("Les menus de la barre de menus changent de langue au prochain lancement.",
                        "Menu bar items switch language at next launch."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(tr("Calendrier fiscal", "Fiscal calendar")) {
                Picker(tr("L'exercice se termine en", "Fiscal year ends in"), selection: Binding(get: { cal.yearEndMonth }, set: { month in
                    var s = store.settings
                    s.calendar.yearEndMonth = month
                    store.updateSettings(s)
                })) {
                    ForEach(1...12, id: \.self) { Text(L10n.fullMonthName($0).capitalized).tag($0) }
                }
                Picker(tr("Les semaines commencent le", "Weeks start on"), selection: Binding(get: { cal.firstWeekday }, set: { day in
                    var s = store.settings
                    s.calendar.firstWeekday = day
                    store.updateSettings(s)
                })) {
                    ForEach(1...7, id: \.self) { Text(L10n.weekdayName($0).capitalized).tag($0) }
                }
                LabeledContent(tr("Exercice en cours", "Current fiscal year")) {
                    Text("\(L10n.fiscalYear(currentFY)) : \(L10n.date(cal.startOfFiscalYear(currentFY))) → \(L10n.date(cal.endOfFiscalYear(currentFY))) · \(cal.weeksInFiscalYear(currentFY)) \(tr("semaines", "weeks"))")
                        .monospacedDigit()
                }
                LabeledContent(tr("Dernière semaine terminée (PWK)", "Last completed week (PWK)")) {
                    Text(L10n.weekLong(store.previousWeek))
                }
                Text(tr("L'exercice se termine le dernier \(L10n.weekdayName(cal.firstWeekday == 1 ? 7 : cal.firstWeekday - 1)) du mois choisi. Trimestres de 13 semaines ; la 53e semaine éventuelle rejoint le T4.",
                        "The fiscal year ends on the last \(L10n.weekdayName(cal.firstWeekday == 1 ? 7 : cal.firstWeekday - 1)) of the chosen month. 13-week quarters; a 53rd week, if any, goes to Q4."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(tr("Données", "Data")) {
                LabeledContent(tr("Fichier", "File")) {
                    Text(store.fileURL?.path ?? tr("En mémoire", "In memory"))
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Text(tr("Les données restent sur ce Mac (fichier lisible par vous seul). Aucune synchronisation cloud.",
                        "Data stays on this Mac (file readable only by you). No cloud sync."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button(tr("Afficher dans le Finder", "Show in Finder")) {
                        if let url = store.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                    Button(tr("Exporter en CSV…", "Export CSV…")) { CSVPanels.exportCSV(store: store) }
                    Button(tr("Importer un CSV…", "Import CSV…")) { CSVPanels.importCSV(store: store) }
                }
                HStack {
                    Button(tr("Recharger les données d'exemple…", "Reload sample data…")) { confirmSample = true }
                    Button(tr("Tout effacer…", "Erase everything…"), role: .destructive) { confirmErase = true }
                }
                if let error = store.saveError { WarningLabel(message: error) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .id(settings.language)
        .confirmationDialog(tr("Remplacer toutes les données par les données d'exemple ?", "Replace all data with the sample data?"),
                            isPresented: $confirmSample) {
            Button(tr("Remplacer", "Replace"), role: .destructive) { store.loadSampleData() }
        } message: {
            Text(tr("Vous pourrez annuler avec ⌥⌘Z.", "You can undo with ⌥⌘Z."))
        }
        .confirmationDialog(tr("Effacer tous les résultats et toutes les valeurs ?", "Erase all results and values?"),
                            isPresented: $confirmErase) {
            Button(tr("Tout effacer", "Erase everything"), role: .destructive) { store.eraseAll() }
        } message: {
            Text(tr("Vous pourrez annuler avec ⌥⌘Z tant que l'app reste ouverte.", "You can undo with ⌥⌘Z while the app stays open."))
        }
    }
}

/// Fenêtres d'import / export CSV.
@MainActor
enum CSVPanels {
    static func exportCSV(store: MetricStore) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "metrixator-\(store.today.iso).csv"
        panel.message = tr("Export de toutes les valeurs hebdomadaires", "Export of all weekly values")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            // BOM UTF-8 pour qu'Excel affiche correctement les accents.
            try ("\u{FEFF}" + store.exportCSV()).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            alert(tr("Export impossible", "Export failed"), error.localizedDescription)
        }
    }

    static func importCSV(store: MetricStore) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.message = tr("Colonnes attendues : resultat ; semaine (AAAA-MM-JJ) ; valeur ; yoy_saisi (optionnel)",
                           "Expected columns: resultat; semaine (YYYY-MM-DD); valeur; yoy_saisi (optional)")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let report = store.importCSV(text)
            var details = report.errors.prefix(8).map { tr("Ligne \($0.line) : \($0.message)", "Line \($0.line): \($0.message)") }
            if !report.duplicates.isEmpty {
                details.append(tr("Doublons bloqués (lignes) : ", "Blocked duplicates (lines): ")
                               + report.duplicates.prefix(15).map(String.init).joined(separator: ", ")
                               + (report.duplicates.count > 15 ? "…" : ""))
            }
            alert(report.summary, details.joined(separator: "\n"))
        } catch {
            alert(tr("Import impossible", "Import failed"), error.localizedDescription)
        }
    }

    private static func alert(_ title: String, _ message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.runModal()
    }
}
#endif
