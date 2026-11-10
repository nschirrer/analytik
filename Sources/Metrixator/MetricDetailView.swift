#if os(macOS)
import MetrixatorCore
import SwiftUI

/// Plage du graphique de la vue détaillée.
enum ChartRange: String, CaseIterable, Identifiable {
    case w13, w26, w52, fiscalYear, all
    var id: String { rawValue }

    var label: String {
        switch self {
        case .w13: return tr("13 sem.", "13 wks")
        case .w26: return tr("26 sem.", "26 wks")
        case .w52: return tr("52 sem.", "52 wks")
        case .fiscalYear: return tr("Exercice", "Fiscal year")
        case .all: return tr("Tout", "All")
        }
    }
}

/// Vue détaillée d'un résultat : saisie, synthèse par période, graphique et historique.
struct MetricDetailView: View {
    @Environment(MetricStore.self) private var store
    @Environment(Router.self) private var router
    let metricID: UUID

    @State private var chartStyle: DisplayStyle = .line
    @State private var range: ChartRange = .w26
    @State private var editingEntry: Entry?

    var body: some View {
        if let metric = store.metric(metricID) {
            let reference = router.referenceWeek(in: store)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(metric)
                    EntryForm(metric: metric)
                    periodGrid(metric, reference: reference)
                    chartCard(metric, reference: reference)
                    historyCard(metric)
                }
                .padding(.horizontal, Theme.contentInset)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle(metric.name)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        router.editor = EditorRequest(metricID: metric.id)
                    } label: {
                        Label(tr("Modifier", "Edit"), systemImage: "slider.horizontal.3")
                    }
                    .help(tr("Modifier le titre, la nature et l'affichage", "Edit title, kind and display"))
                    Button(role: .destructive) {
                        store.deleteMetric(metric.id)
                        router.toast = store.undoLabel
                        if !router.path.isEmpty { router.path.removeLast() }
                    } label: {
                        Label(tr("Supprimer", "Delete"), systemImage: "trash")
                    }
                    .help(tr("Supprimer ce résultat (annulable)", "Delete this result (can be undone)"))
                }
            }
            .sheet(item: $editingEntry) { entry in
                EntryEditSheet(metric: metric, entry: entry)
                    .environment(store)
            }
            .onAppear {
                chartStyle = metric.display.hasChart ? metric.display : .line
            }
        } else {
            ContentUnavailableView(tr("Résultat supprimé", "Result deleted"), systemImage: "trash",
                                   description: Text(tr("Ce résultat n'existe plus.", "This result no longer exists.")))
        }
    }

    // MARK: En-tête

    private func header(_ m: Metric) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.color(m.color))
                .frame(width: 6, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(m.name).font(.largeTitle.weight(.bold))
                if !m.details.isEmpty {
                    Text(m.details).foregroundStyle(.secondary)
                }
                Text([m.kind.label, m.unit.isEmpty ? nil : m.unit, m.aggregation.label,
                      m.higherIsBetter ? tr("hausse = positif", "higher is better") : tr("baisse = positif", "lower is better")]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Synthèse par période

    private func periodGrid(_ m: Metric, reference: FiscalWeek) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Synthèse au \(L10n.weekLong(reference))", "Summary as of \(L10n.weekLong(reference))"))
                .font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(PeriodKind.allCases) { kind in
                    let s = Analytics.summary(of: m, period: kind, reference: reference, calendar: store.calendar)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(kind.shortLabel).font(.headline)
                            Text(kind.label).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            if s.value != nil && !s.isComplete {
                                Text("\(s.weeksWithData)/\(s.weeks.count) " + tr("sem.", "wks"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                        Text(NumberFormat.valueWithUnit(s.value, unit: m.unit, compact: true))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        ChangeBadge(change: s.yoy, inPoints: m.kind.comparesInPoints, higherIsBetter: m.higherIsBetter,
                                    label: "Y/Y" + sourceSuffix(s.yoySource))
                        if let label = Analytics.previousLabel(for: kind) {
                            ChangeBadge(change: s.change, inPoints: m.kind.comparesInPoints, higherIsBetter: m.higherIsBetter,
                                        label: label, font: .caption)
                        } else {
                            // YTD : la valeur N-1 remplace la comparaison avec la période précédente
                            // (même hauteur de carte que les autres).
                            Text(tr("N-1 : ", "LY: ") + NumberFormat.valueWithUnit(s.lastYearValue, unit: m.unit, compact: true))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        Text(L10n.periodCaption(kind, reference: reference, calendar: store.calendar))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .card(padding: 14)
                }
            }
        }
    }

    private func sourceSuffix(_ source: YoYSource?) -> String {
        switch source {
        case .computed: return tr(" (calculé)", " (computed)")
        case .manual: return tr(" (saisi)", " (entered)")
        case .mixed: return tr(" (calculé + saisi)", " (computed + entered)")
        case nil: return ""
        }
    }

    // MARK: Graphique

    private func chartWeeks(reference: FiscalWeek, metric: Metric) -> [FiscalWeek] {
        let cal = store.calendar
        switch range {
        case .w13: return cal.trailingWeeks(13, endingAt: reference)
        case .w26: return cal.trailingWeeks(26, endingAt: reference)
        case .w52: return cal.trailingWeeks(52, endingAt: reference)
        case .fiscalYear:
            return cal.weeks(from: cal.week(fiscalYear: reference.fiscalYear, index: 1)!,
                             to: cal.week(fiscalYear: reference.fiscalYear, index: cal.weeksInFiscalYear(reference.fiscalYear))!)
        case .all:
            guard let first = metric.entries.first else { return cal.trailingWeeks(13, endingAt: reference) }
            return cal.weeks(from: cal.week(containing: first.week), to: reference)
        }
    }

    private func chartCard(_ m: Metric, reference: FiscalWeek) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("Évolution", "Trend")).font(.title3.weight(.semibold))
                Spacer()
                Picker(tr("Format", "Format"), selection: $chartStyle) {
                    Label(DisplayStyle.line.label, systemImage: DisplayStyle.line.symbol).tag(DisplayStyle.line)
                    Label(DisplayStyle.bars.label, systemImage: DisplayStyle.bars.symbol).tag(DisplayStyle.bars)
                    Label(DisplayStyle.versusLastYear.label, systemImage: DisplayStyle.versusLastYear.symbol).tag(DisplayStyle.versusLastYear)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 380)
                Picker(tr("Plage", "Range"), selection: $range) {
                    ForEach(ChartRange.allCases) { r in Text(r.label).tag(r) }
                }
                .labelsHidden()
                .frame(width: 120)
            }
            MetricChart(points: Analytics.series(of: m, weeks: chartWeeks(reference: reference, metric: m), calendar: store.calendar),
                        style: chartStyle, color: Theme.color(m.color), compact: false, calendar: store.calendar)
                .frame(height: 260)
            if chartStyle == .versusLastYear {
                HStack(spacing: 16) {
                    legend(color: Theme.color(m.color), dashed: false, text: tr("Année en cours", "This year"))
                    legend(color: .secondary, dashed: true, text: tr("Même semaine N-1", "Same week last year"))
                }
                .font(.caption)
            }
        }
        .card(padding: 18)
    }

    private func legend(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 4))
                p.addLine(to: CGPoint(x: 18, y: 4))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
            .frame(width: 18, height: 8)
            Text(text).foregroundStyle(.secondary)
        }
    }

    // MARK: Historique

    private func historyCard(_ m: Metric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("Historique", "History")).font(.title3.weight(.semibold))
                Text(tr("\(m.entries.count) semaine(s)", "\(m.entries.count) week(s)")).foregroundStyle(.secondary)
            }
            if m.entries.isEmpty {
                Text(tr("Aucune valeur pour l'instant. Utilisez le formulaire ci-dessus pour saisir la première semaine.",
                        "No values yet. Use the form above to enter the first week."))
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        Text(tr("Semaine", "Week"))
                        Text(tr("Valeur", "Value")).gridColumnAlignment(.trailing)
                        Text("Y/Y").gridColumnAlignment(.trailing)
                        Text(tr("vs sem. préc.", "vs prev. week")).gridColumnAlignment(.trailing)
                        Text("")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    Divider()
                    ForEach(m.entries.reversed()) { entry in
                        historyRow(m, entry)
                    }
                }
            }
        }
        .card(padding: 18)
    }

    @ViewBuilder
    private func historyRow(_ m: Metric, _ entry: Entry) -> some View {
        let cal = store.calendar
        let week = cal.week(containing: entry.week)
        let yoy = Analytics.weeklyYoY(of: m, week: week, calendar: cal)
        let previous = m.entry(for: cal.week(offset: -1, from: week).start)
        let wow = Analytics.change(from: previous?.value, to: entry.value, inPoints: m.kind.comparesInPoints)
        GridRow {
            Text(L10n.weekLong(week))
                .monospacedDigit()
            Text(NumberFormat.valueWithUnit(entry.value, unit: m.unit))
                .monospacedDigit()
            HStack(spacing: 4) {
                Text(yoy.map { NumberFormat.change($0.value, inPoints: m.kind.comparesInPoints) } ?? "—")
                    .foregroundStyle(Theme.changeColor(yoy?.value, higherIsBetter: m.higherIsBetter))
                if let source = yoy?.source {
                    Text(source == .computed ? tr("calc.", "calc.") : tr("saisi", "entered"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            Text(NumberFormat.change(wow, inPoints: m.kind.comparesInPoints))
                .foregroundStyle(Theme.changeColor(wow, higherIsBetter: m.higherIsBetter))
                .monospacedDigit()
            HStack(spacing: 10) {
                Button {
                    editingEntry = entry
                } label: {
                    Image(systemName: "pencil")
                }
                .help(tr("Modifier cette valeur", "Edit this value"))
                Button {
                    store.deleteEntry(metricID: m.id, week: entry.week)
                    router.toast = store.undoLabel
                } label: {
                    Image(systemName: "trash")
                }
                .help(tr("Supprimer cette valeur (annulable)", "Delete this value (can be undone)"))
            }
            .buttonStyle(.borderless)
        }
    }
}

/// Formulaire « Ajouter une semaine » en tête de la vue détaillée.
struct EntryForm: View {
    @Environment(MetricStore.self) private var store
    let metric: Metric

    @State private var week: Day = Day(1970, 1, 1)
    @State private var valueText = ""
    @State private var yoyText = ""
    @State private var submitError: String?
    @State private var confirmation: String?

    var body: some View {
        let cal = store.calendar
        let fiscalWeek = cal.week(containing: week)
        let validation = Validator.validateEntry(valueText: valueText, yoyText: yoyText, metric: metric,
                                                 week: fiscalWeek, today: store.today)
        let lastYear = cal.sameWeekLastYear(fiscalWeek).flatMap { metric.entry(for: $0.start) }

        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Ajouter une semaine", "Add a week")).font(.title3.weight(.semibold))
            HStack(alignment: .center, spacing: 12) {
                WeekPicker(title: tr("Semaine", "Week"), selection: $week, calendar: cal, lastWeek: store.previousWeek,
                           filled: { metric.entry(for: $0) != nil })
                    .frame(width: 300)
                    .onChange(of: week) { submitError = nil; confirmation = nil }

                HStack(spacing: 4) {
                    TextField(tr("Valeur", "Value") + (metric.unit.isEmpty ? "" : " (\(metric.unit))"), text: $valueText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onSubmit { submit(validation) }
                    WarningIcon(message: validation.valueError?.message)
                }

                if let lastYear {
                    let computed = validation.value.flatMap {
                        Analytics.change(from: lastYear.value, to: $0, inPoints: metric.kind.comparesInPoints)
                    }
                    Text(tr("Y/Y calculé : ", "Computed Y/Y: ") + (computed.map { NumberFormat.change($0, inPoints: metric.kind.comparesInPoints) } ?? "—")
                         + tr(" (N-1 : ", " (LY: ") + NumberFormat.valueWithUnit(lastYear.value, unit: metric.unit) + ")")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    HStack(spacing: 4) {
                        TextField(metric.kind.comparesInPoints ? tr("Y/Y en points (optionnel)", "Y/Y in points (optional)")
                                                               : tr("Y/Y en % (optionnel)", "Y/Y in % (optional)"),
                                  text: $yoyText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 170)
                            .onSubmit { submit(validation) }
                        WarningIcon(message: validation.yoyError?.message)
                    }
                }

                Button(tr("Ajouter", "Add")) { submit(validation) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!validation.isValid)
                Spacer(minLength: 0)
            }
            if let weekError = validation.weekError {
                WarningLabel(message: weekError.message)
            }
            ForEach([validation.valueError, validation.yoyError].compactMap { $0 }, id: \.message) { error in
                WarningLabel(message: error.message)
            }
            if let submitError {
                WarningLabel(message: submitError)
            }
            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.positive)
            }
        }
        .card(padding: 18)
        .onAppear { selectDefaultWeek() }
    }

    /// Par défaut : la semaine terminée la plus récente sans valeur, sans remonter avant le début
    /// de l'historique du résultat ; si tout est saisi, la dernière semaine terminée (PWK).
    private func selectDefaultWeek() {
        guard week == Day(1970, 1, 1) else { return }
        week = EntryForm.defaultWeek(for: metric, calendar: store.calendar, lastWeek: store.previousWeek)
    }

    static func defaultWeek(for metric: Metric, calendar: FiscalCalendar, lastWeek: FiscalWeek) -> Day {
        let earliest = metric.entries.first?.week ?? lastWeek.start
        let candidates = calendar.trailingWeeks(104, endingAt: lastWeek).reversed().filter { $0.start >= earliest }
        return candidates.first { metric.entry(for: $0.start) == nil }?.start ?? lastWeek.start
    }

    private func submit(_ validation: EntryValidation) {
        guard validation.isValid, let value = validation.value else { return }
        do {
            let hasLastYear = store.calendar.sameWeekLastYear(store.calendar.week(containing: week))
                .flatMap { metric.entry(for: $0.start) } != nil
            try store.addEntry(metricID: metric.id, week: week, value: value, manualYoY: hasLastYear ? nil : validation.manualYoY)
            confirmation = tr("Valeur enregistrée pour ", "Value saved for ") + L10n.weekLong(store.calendar.week(containing: week))
            submitError = nil
            valueText = ""
            yoyText = ""
            if let next = store.metric(metric.id) {
                week = EntryForm.defaultWeek(for: next, calendar: store.calendar, lastWeek: store.previousWeek)
            }
        } catch let error as MetrixError {
            submitError = error.message
        } catch {
            submitError = error.localizedDescription
        }
    }
}

/// Modification d'une valeur existante.
struct EntryEditSheet: View {
    @Environment(MetricStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let metric: Metric
    let entry: Entry

    @State private var valueText = ""
    @State private var yoyText = ""
    @State private var error: String?

    var body: some View {
        let cal = store.calendar
        let week = cal.week(containing: entry.week)
        let validation = Validator.validateEntry(valueText: valueText, yoyText: yoyText, metric: metric, week: week,
                                                 today: store.today, isEditingExisting: true)
        let hasLastYear = cal.sameWeekLastYear(week).flatMap { metric.entry(for: $0.start) } != nil
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Modifier la valeur", "Edit value")).font(.title2.weight(.semibold))
            Text(metric.name + " · " + L10n.weekLong(week)).foregroundStyle(.secondary)
            Form {
                HStack {
                    TextField(tr("Valeur", "Value"), text: $valueText)
                    WarningIcon(message: validation.valueError?.message)
                }
                if hasLastYear {
                    Text(tr("Y/Y calculé automatiquement à partir de la même semaine N-1.",
                            "Y/Y computed automatically from the same week last year."))
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        TextField(metric.kind.comparesInPoints ? tr("Y/Y en points (optionnel)", "Y/Y in points (optional)")
                                                               : tr("Y/Y en % (optionnel)", "Y/Y in % (optional)"), text: $yoyText)
                        WarningIcon(message: validation.yoyError?.message)
                    }
                }
            }
            ForEach(validation.errors, id: \.message) { WarningLabel(message: $0.message) }
            if let error { WarningLabel(message: error) }
            HStack {
                Spacer()
                Button(tr("Annuler", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(tr("Enregistrer", "Save")) {
                    guard let value = validation.value else { return }
                    do {
                        try store.updateEntry(metricID: metric.id, week: entry.week, value: value,
                                              manualYoY: hasLastYear ? entry.manualYoY : validation.manualYoY)
                        dismiss()
                    } catch let e as MetrixError {
                        error = e.message
                    } catch let e {
                        error = e.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!validation.isValid)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            valueText = NumberFormat.plain(entry.value, maxDecimals: 6).replacingOccurrences(of: "\u{202F}", with: " ")
            yoyText = entry.manualYoY.map { NumberFormat.plain($0, maxDecimals: 4) } ?? ""
        }
    }
}
#endif
