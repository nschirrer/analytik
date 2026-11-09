#if os(macOS)
import MetrixatorCore
import SwiftUI

/// Écran d'accueil : tableau de synthèse des résultats suivis.
struct DashboardView: View {
    @Environment(MetricStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let reference = router.referenceWeek(in: store)
        let visible = store.metrics.filter(\.showOnDashboard)
        Group {
            if store.metrics.isEmpty {
                ContentUnavailableView {
                    Label(tr("Aucun résultat suivi", "No tracked results"), systemImage: "chart.bar.doc.horizontal")
                } description: {
                    Text(tr("Créez les chiffres à suivre ce trimestre, puis saisissez leurs valeurs chaque semaine.",
                            "Create the figures to track this quarter, then enter their values each week."))
                } actions: {
                    Button(tr("Ajouter un résultat", "Add a result")) { router.editor = EditorRequest(metricID: nil) }
                        .buttonStyle(.borderedProminent)
                    Button(tr("Charger les données d'exemple", "Load sample data")) { store.loadSampleData() }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        DashboardHeader(reference: reference, hidden: store.metrics.count - visible.count)
                        if visible.isEmpty {
                            Text(tr("Tous les résultats sont masqués. Affichez-les depuis « Résultats suivis ».",
                                    "All results are hidden. Show them from “Tracked results”."))
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                                .frame(maxWidth: .infinity)
                        }
                        MasonryLayout(minColumnWidth: 270, spacing: 14) {
                            ForEach(visible) { metric in
                                MetricTile(metric: metric, period: store.settings.period, reference: reference)
                                    .onTapGesture { router.path.append(metric.id) }
                                    .contextMenu { TileMenu(metric: metric) }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Theme.canvas)
        .navigationTitle(tr("Tableau de synthèse", "Dashboard"))
        .toolbar { toolbar(reference: reference) }
    }
}

extension DashboardView {
    @ToolbarContentBuilder
    func toolbar(reference: FiscalWeek) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker(tr("Période", "Period"), selection: Binding(get: { store.settings.period }, set: { store.setPeriod($0) })) {
                ForEach(PeriodKind.allCases) { p in
                    Text(p.shortLabel).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .help(tr("Période affichée : PWK = semaine précédente, L4W = 4 dernières semaines, QTD = trimestre à date, YTD = exercice à date",
                     "Displayed period: PWK = previous week, L4W = last 4 weeks, QTD = quarter to date, YTD = year to date"))
        }
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 2) {
                Button {
                    router.weekOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help(tr("Semaine précédente", "Previous week"))
                Button {
                    router.weekOffset = 0
                } label: {
                    Text(L10n.weekShort(reference))
                        .monospacedDigit()
                        .frame(minWidth: 78)
                }
                .help(router.weekOffset == 0
                      ? tr("Semaine de référence : dernière semaine terminée (\(L10n.weekLong(reference)))",
                           "Reference week: last completed week (\(L10n.weekLong(reference)))")
                      : tr("Revenir à la dernière semaine terminée", "Back to the last completed week"))
                Button {
                    router.weekOffset = min(0, router.weekOffset + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(router.weekOffset >= 0)
                .help(tr("Semaine suivante", "Next week"))
            }
            Button {
                router.showWeeklyEntry = true
            } label: {
                Label(tr("Saisir la semaine", "Enter the week"), systemImage: "square.and.pencil")
            }
            .help(tr("Saisir les valeurs de la semaine pour tous les résultats (⌘E)", "Enter this week's values for all results (⌘E)"))
            Button {
                router.editor = EditorRequest(metricID: nil)
            } label: {
                Label(tr("Nouveau résultat", "New result"), systemImage: "plus")
            }
            .help(tr("Ajouter un résultat à suivre (⌘N)", "Add a result to track (⌘N)"))
        }
    }
}

struct DashboardHeader: View {
    @Environment(MetricStore.self) private var store
    let reference: FiscalWeek
    let hidden: Int

    var body: some View {
        let period = store.settings.period
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(period.label)
                .font(.title2.weight(.semibold))
            Text(L10n.periodCaption(period, reference: reference, calendar: store.calendar))
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            if hidden > 0 {
                Text(tr("\(hidden) masqué(s)", "\(hidden) hidden"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TileMenu: View {
    @Environment(MetricStore.self) private var store
    @Environment(Router.self) private var router
    let metric: Metric

    var body: some View {
        Button(tr("Ouvrir le détail", "Open details")) { router.path.append(metric.id) }
        Button(tr("Modifier…", "Edit…")) { router.editor = EditorRequest(metricID: metric.id) }
        Menu(tr("Format d'affichage", "Display format")) {
            ForEach(DisplayStyle.allCases) { style in
                Button {
                    var m = metric
                    m.display = style
                    try? store.updateMetric(m)
                } label: {
                    if style == metric.display {
                        Label(style.label, systemImage: "checkmark")
                    } else {
                        Text(style.label)
                    }
                }
            }
        }
        Button(tr("Masquer du tableau", "Hide from dashboard")) {
            var m = metric
            m.showOnDashboard = false
            try? store.updateMetric(m)
        }
        Divider()
        Button(tr("Supprimer", "Delete"), role: .destructive) {
            store.deleteMetric(metric.id)
            router.toast = store.undoLabel
        }
    }
}

/// Disposition en colonnes « maçonnerie » : chaque tuile va dans la colonne la moins haute.
struct MasonryLayout: Layout {
    var minColumnWidth: CGFloat = 270
    var spacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(proposal.width)
        let frames = frames(width: width, subviews: subviews)
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(width: bounds.width, subviews: subviews)
        for (index, frame) in frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  anchor: .topLeading,
                                  proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func resolvedWidth(_ proposed: CGFloat?) -> CGFloat {
        guard let proposed, proposed.isFinite, proposed > 0 else { return 1100 }
        return proposed
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let columns = max(1, Int((width + spacing) / (minColumnWidth + spacing)))
        let columnWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var heights = Array(repeating: CGFloat(0), count: columns)
        var result: [CGRect] = []
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            var column = 0
            for c in 1..<columns where heights[c] < heights[column] - 1 { column = c }
            result.append(CGRect(x: CGFloat(column) * (columnWidth + spacing), y: heights[column], width: columnWidth, height: height))
            heights[column] += height + spacing
        }
        return result
    }
}
#endif
