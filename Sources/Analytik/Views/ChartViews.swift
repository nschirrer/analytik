import Charts
import SwiftUI
import AnalytikCore

struct ChartPoint: Identifiable {
    let id: String
    let series: String
    let period: String
    let value: Double
}

enum ChartData {
    /// Étiquettes d'axe : « W1 » si toutes les colonnes sont dans le même trimestre, sinon « Q3 W1 » ou « FY26 Q3 W1 ».
    static func axisLabels(for columns: [Period]) -> [String] {
        let years = Set(columns.compactMap { $0.fiscalYear })
        let quarters = Set(columns.compactMap { period -> String? in
            guard let fy = period.fiscalYear, let q = period.quarterNumber else { return nil }
            return "\(fy)-\(q)"
        })
        return columns.map { period in
            switch period {
            case let .week(fy, q, w):
                if years.count > 1 { return "FY\(fy % 100) Q\(q) W\(w)" }
                if quarters.count > 1 { return "Q\(q) W\(w)" }
                return "W\(w)"
            case let .quarter(fy, q):
                return years.count > 1 ? "Q\(q) FY\(fy % 100)" : "Q\(q)"
            case let .opaque(label, _):
                return label
            }
        }
    }

    static func seriesLabels(from table: PivotTable, includeTotal: Bool) -> [String] {
        table.rows.filter { includeTotal || !$0.isTotal }.map { $0.label }
    }

    static func points(from table: PivotTable, includeTotal: Bool) -> [ChartPoint] {
        let labels = axisLabels(for: table.columns)
        var points: [ChartPoint] = []
        for row in table.rows where includeTotal || !row.isTotal {
            for (index, period) in table.columns.enumerated() {
                guard let value = row.values[period.id] else { continue }
                let scaled = table.metric.isRatio ? value * 100 : value
                points.append(ChartPoint(id: row.id + "|" + period.id, series: row.label, period: labels[index], value: scaled))
            }
        }
        return points
    }
}

struct ChartContainerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let table = model.pivotTable
        let allSeries = ChartData.seriesLabels(from: table, includeTotal: model.chartIncludesTotal)
        let shownSeries = Array(allSeries.prefix(ChartPalette.maxSeries))
        let points = ChartData.points(from: table, includeTotal: model.chartIncludesTotal)
            .filter { shownSeries.contains($0.series) }
        let axisLabels = ChartData.axisLabels(for: table.columns)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Picker("Type de graphique", selection: $model.chartKind) {
                    ForEach(ChartKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
                if model.series == .member {
                    Toggle("Inclure la ligne TOTAL", isOn: $model.chartIncludesTotal)
                        .toggleStyle(.checkbox)
                }
                if allSeries.count > ChartPalette.maxSeries {
                    Label("Seules les \(ChartPalette.maxSeries) premières lignes sont tracées ; masquez des lignes pour en voir d'autres.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if points.isEmpty {
                ContentUnavailableView(
                    "Rien à tracer",
                    systemImage: "chart.bar",
                    description: Text("Aucune valeur disponible pour cette sélection.")
                )
            } else if model.chartKind == .bar {
                BarChartView(points: points, seriesLabels: shownSeries, axisLabels: axisLabels, metric: table.metric)
            } else {
                LineChartView(points: points, seriesLabels: shownSeries, axisLabels: axisLabels, metric: table.metric)
            }
        }
    }
}

struct BarChartView: View {
    let points: [ChartPoint]
    let seriesLabels: [String]
    let axisLabels: [String]
    let metric: Metric

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Période", point.period),
                y: .value(metric.frenchName, point.value)
            )
            .foregroundStyle(by: .value("Ligne", point.series))
            .position(by: .value("Ligne", point.series))
            .cornerRadius(2)
        }
        .chartXScale(domain: axisLabels)
        .chartForegroundStyleScale(domain: seriesLabels, range: ChartPalette.colors(count: seriesLabels.count))
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYAxisLabel(metric.isRatio ? "%" : "Unités")
        .padding(12)
    }
}

struct LineChartView: View {
    let points: [ChartPoint]
    let seriesLabels: [String]
    let axisLabels: [String]
    let metric: Metric

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Période", point.period),
                y: .value(metric.frenchName, point.value)
            )
            .foregroundStyle(by: .value("Ligne", point.series))
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2))
            PointMark(
                x: .value("Période", point.period),
                y: .value(metric.frenchName, point.value)
            )
            .foregroundStyle(by: .value("Ligne", point.series))
            .symbolSize(36)
        }
        .chartXScale(domain: axisLabels)
        .chartForegroundStyleScale(domain: seriesLabels, range: ChartPalette.colors(count: seriesLabels.count))
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYAxisLabel(metric.isRatio ? "%" : "Unités")
        .padding(12)
    }
}
