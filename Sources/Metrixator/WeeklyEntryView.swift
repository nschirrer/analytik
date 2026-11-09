#if os(macOS)
import MetrixatorCore
import SwiftUI

/// Saisie rapide du lundi : une ligne par résultat pour la semaine choisie.
struct WeeklyEntryView: View {
    @Environment(MetricStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var week: Day = Day(1970, 1, 1)
    @State private var values: [UUID: String] = [:]
    @State private var yoys: [UUID: String] = [:]
    @State private var errors: [String] = []

    var body: some View {
        let cal = store.calendar
        let fiscalWeek = cal.week(containing: week)
        let rows = makeRows(week: fiscalWeek)
        let pending = rows.filter { $0.existing == nil && !(values[$0.metric.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        let invalid = pending.filter { !$0.validation.isValid }
        let filledCount = rows.filter { $0.existing != nil }.count

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Saisie de la semaine", "Weekly entry")).font(.title2.weight(.semibold))
                HStack {
                    WeekPicker(title: tr("Semaine", "Week"), selection: $week, calendar: cal, lastWeek: store.previousWeek)
                        .frame(width: 320)
                    Text(tr("\(filledCount)/\(rows.count) déjà saisis", "\(filledCount)/\(rows.count) already entered"))
                        .foregroundStyle(.secondary)
                }
                Text(tr("Les résultats déjà saisis pour cette semaine sont verrouillés (modifiez-les depuis leur historique). Le Y/Y est calculé automatiquement quand la semaine N-1 existe.",
                        "Results already entered for this week are locked (edit them from their history). Y/Y is computed automatically when last year's week exists."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    GridRow {
                        Text(tr("Résultat", "Result"))
                        Text(tr("Valeur", "Value"))
                        Text("Y/Y")
                        Text("")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    ForEach(rows, id: \.metric.id) { row in
                        GridRow {
                            HStack(spacing: 8) {
                                Circle().fill(Theme.color(row.metric.color)).frame(width: 8, height: 8)
                                Text(row.metric.name).lineLimit(1)
                                if !row.metric.unit.isEmpty {
                                    Text(row.metric.unit).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .frame(width: 300, alignment: .leading)
                            if let existing = row.existing {
                                Text(NumberFormat.valueWithUnit(existing.value, unit: row.metric.unit))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 140, alignment: .leading)
                                Text(Analytics.weeklyYoY(of: row.metric, week: fiscalWeek, calendar: cal)
                                        .map { NumberFormat.change($0.value, inPoints: row.metric.kind.comparesInPoints) } ?? "—")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 150, alignment: .leading)
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.positive)
                                    .help(tr("Déjà saisi", "Already entered"))
                            } else {
                                TextField(tr("Valeur", "Value"), text: binding(for: row.metric.id, in: $values))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 140)
                                if row.lastYear != nil {
                                    let computed = row.validation.value.flatMap {
                                        Analytics.change(from: row.lastYear?.value, to: $0, inPoints: row.metric.kind.comparesInPoints)
                                    }
                                    Text(computed.map { NumberFormat.change($0, inPoints: row.metric.kind.comparesInPoints) + tr(" calc.", " calc.") }
                                         ?? tr("calculé", "computed"))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                        .frame(width: 150, alignment: .leading)
                                } else {
                                    TextField(row.metric.kind.comparesInPoints ? tr("pts (opt.)", "pts (opt.)") : tr("% (opt.)", "% (opt.)"),
                                              text: binding(for: row.metric.id, in: $yoys))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 150)
                                }
                                WarningIcon(message: warningMessage(row))
                                    .frame(width: 20)
                            }
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                if !invalid.isEmpty {
                    WarningLabel(message: tr("\(invalid.count) saisie(s) incorrecte(s) à corriger (survolez ⚠︎).",
                                             "\(invalid.count) incorrect entr(ies) to fix (hover ⚠︎)."))
                }
                ForEach(errors, id: \.self) { WarningLabel(message: $0) }
                Spacer()
                Button(tr("Fermer", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(tr("Enregistrer \(pending.count) valeur(s)", "Save \(pending.count) value(s)")) {
                    save(pending)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pending.isEmpty || !invalid.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 780, height: 640)
        .onAppear {
            if week == Day(1970, 1, 1) { week = store.previousWeek.start }
        }
        .onChange(of: week) {
            values = [:]
            yoys = [:]
            errors = []
        }
    }

    struct Row {
        let metric: Metric
        let existing: Entry?
        let lastYear: Entry?
        let validation: EntryValidation
    }

    private func makeRows(week fiscalWeek: FiscalWeek) -> [Row] {
        let cal = store.calendar
        return store.metrics.map { m in
            Row(metric: m,
                existing: m.entry(for: fiscalWeek.start),
                lastYear: cal.sameWeekLastYear(fiscalWeek).flatMap { m.entry(for: $0.start) },
                validation: Validator.validateEntry(valueText: values[m.id] ?? "", yoyText: yoys[m.id] ?? "", metric: m,
                                                    week: fiscalWeek, today: store.today))
        }
    }

    /// Message d'alerte d'une ligne, seulement si l'utilisateur a commencé à la remplir.
    private func warningMessage(_ row: Row) -> String? {
        let typed = !(values[row.metric.id] ?? "").isEmpty || !(yoys[row.metric.id] ?? "").isEmpty
        guard typed else { return nil }
        return row.validation.errors.first?.message
    }

    private func binding(for id: UUID, in dict: Binding<[UUID: String]>) -> Binding<String> {
        Binding(get: { dict.wrappedValue[id] ?? "" }, set: { dict.wrappedValue[id] = $0 })
    }

    private func save(_ items: [Row]) {
        var failures: [String] = []
        for row in items {
            let metric = row.metric
            let validation = row.validation
            let hasLastYear = row.lastYear != nil
            guard let value = validation.value else { continue }
            do {
                try store.addEntry(metricID: metric.id, week: week, value: value, manualYoY: hasLastYear ? nil : validation.manualYoY)
                values[metric.id] = nil
                yoys[metric.id] = nil
            } catch let error as MetrixError {
                failures.append("\(metric.name) : \(error.message)")
            } catch {
                failures.append("\(metric.name) : \(error.localizedDescription)")
            }
        }
        errors = failures
        if failures.isEmpty { dismiss() }
    }
}
#endif
