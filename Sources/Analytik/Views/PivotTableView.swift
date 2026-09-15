import SwiftUI
import AnalytikCore

struct PivotTableView: View {
    let table: PivotTable

    var body: some View {
        if table.isEmpty {
            ContentUnavailableView(
                "Rien à afficher",
                systemImage: "tablecells",
                description: Text("Aucune période ou aucune ligne ne correspond aux filtres.")
            )
        } else {
            Table(table.rows) {
                TableColumn(table.seriesTitle) { (row: PivotRow) in
                    Text(row.label)
                        .fontWeight(row.isTotal ? .semibold : .regular)
                }
                .width(min: 150, ideal: 220)

                TableColumnForEach(table.columns) { period in
                    TableColumn(period.shortLabel) { (row: PivotRow) in
                        NumberCell(text: Formatters.cell(row.value(for: period), metric: table.metric), emphasized: row.isTotal)
                    }
                    .width(min: 64, ideal: 84)
                }

                TableColumn("Total") { (row: PivotRow) in
                    NumberCell(text: Formatters.cell(row.total, metric: table.metric), emphasized: true)
                }
                .width(min: 80, ideal: 100)
            }
        }
    }
}

struct NumberCell: View {
    let text: String
    let emphasized: Bool

    var body: some View {
        Text(text)
            .monospacedDigit()
            .fontWeight(emphasized ? .semibold : .regular)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
