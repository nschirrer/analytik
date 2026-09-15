import SwiftUI
import AnalytikCore

struct ComparisonView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Comparer", selection: $model.comparisonMode) {
                    ForEach(ComparisonMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 380)

                if model.comparisonMode == .lastYear {
                    Text("Ventes de l'année en cours (NBL) contre l'année précédente (LY), cumulées sur les périodes affichées.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("A", selection: bindingA) {
                        ForEach(model.comparisonOptions) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .frame(maxWidth: 260)
                    Text("contre")
                        .foregroundStyle(.secondary)
                    Picker("B", selection: bindingB) {
                        ForEach(model.comparisonOptions) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .frame(maxWidth: 260)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            ComparisonTableView(table: model.comparisonTable)
        }
    }

    private var bindingA: Binding<String> {
        Binding(get: { model.resolvedComparisonA }, set: { model.comparisonA = $0 })
    }

    private var bindingB: Binding<String> {
        Binding(get: { model.resolvedComparisonB }, set: { model.comparisonB = $0 })
    }
}

struct ComparisonTableView: View {
    let table: ComparisonTable

    var body: some View {
        if table.isEmpty {
            ContentUnavailableView(
                "Rien à comparer",
                systemImage: "arrow.left.arrow.right",
                description: Text("Il faut au moins deux périodes ou deux lignes affichées.")
            )
        } else {
            Table(table.rows) {
                TableColumn(table.rowsTitle) { (row: ComparisonRow) in
                    Text(row.label)
                        .fontWeight(row.isTotal ? .semibold : .regular)
                }
                .width(min: 150, ideal: 220)
                TableColumn(table.titleA) { (row: ComparisonRow) in
                    NumberCell(text: Formatters.cell(row.a, metric: table.metric), emphasized: row.isTotal)
                }
                TableColumn(table.titleB) { (row: ComparisonRow) in
                    NumberCell(text: Formatters.cell(row.b, metric: table.metric), emphasized: row.isTotal)
                }
                TableColumn("Écart") { (row: ComparisonRow) in
                    DeltaCell(text: Formatters.delta(row.delta, metric: table.metric), value: row.delta)
                }
                TableColumn("Écart %") { (row: ComparisonRow) in
                    DeltaCell(text: table.showsDeltaPercent ? Formatters.deltaPercent(row.deltaPct) : "", value: row.deltaPct)
                }
            }
        }
    }
}

struct DeltaCell: View {
    let text: String
    let value: Double?

    var body: some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var color: Color {
        guard let value = value, value != 0 else { return .primary }
        return value > 0 ? ChartPalette.positive : ChartPalette.negative
    }
}
