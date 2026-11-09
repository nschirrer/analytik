#if os(macOS)
import MetrixatorCore
import SwiftUI

/// Création / modification d'un résultat à suivre, avec aperçu de la tuile.
struct MetricEditorView: View {
    @Environment(MetricStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let metricID: UUID?

    @State private var draft = Metric(name: "")
    @State private var loaded = false
    @State private var saveError: String?
    @State private var nameTouched = false

    var body: some View {
        let nameError = Validator.validateName(draft.name, among: store.metrics, excluding: metricID)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                form(nameError: nameError)
                    .frame(width: 440)
                preview
                    .frame(width: 300)
            }
            .padding(20)
            Divider()
            HStack {
                if let saveError { WarningLabel(message: saveError) }
                Spacer()
                Button(tr("Annuler", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(metricID == nil ? tr("Créer le résultat", "Create result") : tr("Enregistrer", "Save")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(nameError != nil)
            }
            .padding(16)
        }
        .frame(minHeight: 560)
        .onAppear(perform: load)
    }

    private func form(nameError: MetrixError?) -> some View {
        Form {
            Section(tr("Résultat", "Result")) {
                HStack {
                    TextField(tr("Titre", "Title"), text: $draft.name, prompt: Text(tr("ex. Chiffre d'affaires", "e.g. Revenue")))
                        .onChange(of: draft.name) { nameTouched = true }
                    if nameTouched { WarningIcon(message: nameError?.message) }
                }
                if nameTouched, let nameError {
                    WarningLabel(message: nameError.message)
                }
                TextField(tr("Description", "Description"), text: $draft.details,
                          prompt: Text(tr("Source, définition, objectif…", "Source, definition, target…")), axis: .vertical)
                    .lineLimit(2...4)
            }

            Section(tr("Nature du chiffre", "Kind of figure")) {
                Picker(tr("Nature", "Kind"), selection: $draft.kind) {
                    ForEach(ValueKind.allCases) { kind in Text(kind.label).tag(kind) }
                }
                .onChange(of: draft.kind) { old, new in
                    if draft.unit == old.defaultUnit { draft.unit = new.defaultUnit }
                    if draft.aggregation == old.defaultAggregation { draft.aggregation = new.defaultAggregation }
                }
                TextField(tr("Unité", "Unit"), text: $draft.unit, prompt: Text(tr("€, unités, %, jours…", "€, units, %, days…")))
                Picker(tr("Sur plusieurs semaines", "Across several weeks"), selection: $draft.aggregation) {
                    ForEach(Aggregation.allCases) { a in Text(a.label).tag(a) }
                }
                Picker(tr("Sens", "Direction"), selection: $draft.higherIsBetter) {
                    Text(tr("Une hausse est positive", "Higher is better")).tag(true)
                    Text(tr("Une baisse est positive", "Lower is better")).tag(false)
                }
                Text(draft.kind.comparesInPoints
                     ? tr("Les progressions de ce chiffre s'expriment en points.", "Changes for this figure are shown in points.")
                     : tr("Les progressions de ce chiffre s'expriment en %.", "Changes for this figure are shown in %."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(tr("Affichage", "Display")) {
                Picker(tr("Format", "Format"), selection: $draft.display) {
                    ForEach(DisplayStyle.allCases) { style in
                        Label(style.label, systemImage: style.symbol).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                LabeledContent(tr("Couleur", "Color")) {
                    HStack(spacing: 6) {
                        ForEach(MetricColor.allCases) { c in
                            Button {
                                draft.color = c
                            } label: {
                                Circle()
                                    .fill(Theme.color(c))
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(draft.color == c ? 0.8 : 0), lineWidth: 2).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .help(c.label)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Toggle(tr("Afficher sur le tableau de synthèse", "Show on the dashboard"), isOn: $draft.showOnDashboard)
            }
        }
        .formStyle(.grouped)
    }

    private var preview: some View {
        let reference = store.previousWeek
        var sample = draft
        let isDemo = sample.entries.isEmpty
        if isDemo { sample.entries = MetricEditorView.demoEntries(for: draft, calendar: store.calendar, reference: reference) }
        if sample.name.trimmingCharacters(in: .whitespaces).isEmpty { sample.name = tr("Nouveau résultat", "New result") }
        return VStack(alignment: .leading, spacing: 10) {
            Text(tr("Aperçu", "Preview")).font(.headline)
            MetricTile(metric: sample, period: store.settings.period, reference: reference)
            if isDemo {
                Text(tr("Aperçu avec des valeurs fictives.", "Preview with made-up values."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.canvas))
    }

    /// Série fictive pour l'aperçu d'un résultat sans données.
    static func demoEntries(for m: Metric, calendar cal: FiscalCalendar, reference: FiscalWeek) -> [Entry] {
        let base: Double
        switch m.kind {
        case .currency: base = 48_000
        case .units: base = 1_250
        case .percent: base = 36
        case .score: base = 70
        }
        let weeks = cal.trailingWeeks(65, endingAt: reference)
        return weeks.enumerated().map { i, w in
            let wave = sin(Double(i) / 2.3) * 0.08 + cos(Double(i) / 5.1) * 0.05
            let trend = w.fiscalYear == reference.fiscalYear ? 1.06 : 1.0
            let v = m.kind.comparesInPoints ? base + wave * 20 + (trend - 1) * 30 : base * (1 + wave) * trend
            return Entry(week: w.start, value: (v * 10).rounded() / 10)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let metricID, let existing = store.metric(metricID) {
            draft = existing
        } else {
            let used = Set(store.metrics.map(\.color))
            draft = Metric(name: "", kind: .units, display: .line,
                           color: MetricColor.allCases.first { !used.contains($0) } ?? MetricColor.allCases[store.metrics.count % MetricColor.allCases.count])
        }
        nameTouched = metricID != nil
    }

    private func save() {
        do {
            if metricID == nil {
                try store.addMetric(draft)
            } else {
                try store.updateMetric(draft)
            }
            dismiss()
        } catch let error as MetrixError {
            saveError = error.message
            nameTouched = true
        } catch {
            saveError = error.localizedDescription
        }
    }
}
#endif
