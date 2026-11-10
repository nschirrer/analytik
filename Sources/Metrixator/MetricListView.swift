#if os(macOS)
import MetrixatorCore
import SwiftUI

/// Liste de tous les résultats suivis : modifier, supprimer, réordonner, masquer.
struct MetricListView: View {
    @Environment(MetricStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Group {
            if store.metrics.isEmpty {
                ContentUnavailableView {
                    Label(tr("Aucun résultat suivi", "No tracked results"), systemImage: "list.bullet.rectangle")
                } description: {
                    Text(tr("Ajoutez un premier résultat à suivre.", "Add a first result to track."))
                } actions: {
                    Button(tr("Ajouter un résultat", "Add a result")) { router.editor = EditorRequest(metricID: nil) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("\(store.metrics.count) résultats — glissez pour changer l'ordre du tableau de synthèse",
                            "\(store.metrics.count) results — drag to reorder the dashboard"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Theme.contentInset)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                    List {
                        ForEach(store.metrics) { metric in
                            NavigationLink(value: metric.id) {
                                MetricRow(metric: metric)
                            }
                            .contextMenu { TileMenu(metric: metric) }
                        }
                        .onMove { offsets, destination in
                            store.moveMetrics(fromOffsets: offsets, toOffset: destination)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .screenBackground()
        .navigationTitle(tr("Résultats suivis", "Tracked results"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    CSVPanels.importCSV(store: store)
                } label: {
                    Label(tr("Importer CSV", "Import CSV"), systemImage: "square.and.arrow.down")
                }
                .help(tr("Importer des valeurs depuis un fichier CSV (⇧⌘I)", "Import values from a CSV file (⇧⌘I)"))
                Button {
                    CSVPanels.exportCSV(store: store)
                } label: {
                    Label(tr("Exporter CSV", "Export CSV"), systemImage: "square.and.arrow.up")
                }
                .help(tr("Exporter toutes les valeurs en CSV (⇧⌘E)", "Export all values to CSV (⇧⌘E)"))
                Button {
                    router.editor = EditorRequest(metricID: nil)
                } label: {
                    Label(tr("Nouveau résultat", "New result"), systemImage: "plus")
                }
            }
        }
    }
}

struct MetricRow: View {
    @Environment(MetricStore.self) private var store
    @Environment(Router.self) private var router
    let metric: Metric

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.display.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.color(metric.color)))
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name).font(.body.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let last = metric.lastEntry {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(NumberFormat.valueWithUnit(last.value, unit: metric.unit, compact: true))
                        .monospacedDigit()
                    Text(L10n.weekShort(store.calendar.week(containing: last.week)))
                        .font(.caption)
                        .foregroundStyle(last.week == store.previousWeek.start ? Color.secondary : Theme.warning)
                }
            } else {
                Text(tr("Aucune donnée", "No data")).foregroundStyle(.secondary)
            }
            Button {
                var m = metric
                m.showOnDashboard.toggle()
                try? store.updateMetric(m)
            } label: {
                Image(systemName: metric.showOnDashboard ? "eye" : "eye.slash")
                    .foregroundStyle(metric.showOnDashboard ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(metric.showOnDashboard ? tr("Affiché sur le tableau de synthèse — cliquer pour masquer", "Shown on the dashboard — click to hide")
                                         : tr("Masqué du tableau de synthèse — cliquer pour afficher", "Hidden from the dashboard — click to show"))
            Button {
                router.editor = EditorRequest(metricID: metric.id)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help(tr("Modifier", "Edit"))
            Button {
                store.deleteMetric(metric.id)
                router.toast = store.undoLabel
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(tr("Supprimer (annulable)", "Delete (can be undone)"))
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        [metric.kind.label, metric.display.label, tr("\(metric.entries.count) semaine(s)", "\(metric.entries.count) week(s)")]
            .joined(separator: " · ")
    }
}
#endif
