#if os(macOS)
import Charts
import MetrixatorCore
import SwiftUI

/// Tuile d'un résultat sur le tableau de synthèse.
struct MetricTile: View {
    @Environment(MetricStore.self) private var store
    let metric: Metric
    let period: PeriodKind
    let reference: FiscalWeek
    /// Calendrier à utiliser (aperçu de l'éditeur) ; par défaut celui du store.
    var calendarOverride: FiscalCalendar?

    var body: some View {
        let calendar = calendarOverride ?? store.calendar
        let summary = Analytics.summary(of: metric, period: period, reference: reference, calendar: calendar)
        let color = Theme.color(metric.color)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(metric.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                completenessBadge(summary)
            }

            if metric.display == .yoy {
                yoyBody(summary)
            } else {
                valueBody(summary)
            }

            if metric.display.hasChart {
                let weeks = Analytics.chartWeeks(for: period, reference: reference, calendar: calendar)
                MetricChart(points: Analytics.series(of: metric, weeks: weeks, calendar: calendar),
                            style: metric.display, color: color, compact: true, calendar: calendar)
                    .frame(height: 74)
            }
        }
        .card()
        .contentShape(Rectangle())
        .help(metric.details.isEmpty ? tr("Cliquer pour voir le détail et saisir une valeur", "Click to see details and enter a value") : metric.details)
    }

    // MARK: Contenus

    private func valueBody(_ s: PeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(NumberFormat.value(s.value))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(s.value == nil ? Color.secondary : Color.primary)
                VStack(alignment: .leading, spacing: 0) {
                    if !metric.unit.isEmpty {
                        Text(metric.unit).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text(s.value == nil ? tr("Aucune donnée", "No data") : periodShort)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if s.value != nil {
                HStack(spacing: 12) {
                    ChangeBadge(change: s.yoy, inPoints: metric.kind.comparesInPoints, higherIsBetter: metric.higherIsBetter, label: "Y/Y")
                    if let label = Analytics.previousLabel(for: period), s.change != nil {
                        ChangeBadge(change: s.change, inPoints: metric.kind.comparesInPoints, higherIsBetter: metric.higherIsBetter,
                                    label: label, font: .caption)
                    }
                }
            }
        }
    }

    private func yoyBody(_ s: PeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let yoy = s.yoy, abs(yoy) >= 0.05 {
                    Image(systemName: yoy > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 26, weight: .bold))
                }
                Text(s.yoy == nil ? "—" : NumberFormat.change(s.yoy, inPoints: metric.kind.comparesInPoints))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Y/Y").font(.subheadline.weight(.semibold))
                    Text(periodShort).font(.subheadline).lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            .foregroundStyle(s.yoy == nil ? Color.secondary : Theme.changeColor(s.yoy, higherIsBetter: metric.higherIsBetter))

            if s.value != nil {
                HStack(spacing: 4) {
                    Text(NumberFormat.valueWithUnit(s.value, unit: metric.unit, compact: true))
                        .font(.callout.weight(.semibold))
                    Text(tr("vs", "vs") + " " + NumberFormat.valueWithUnit(s.lastYearValue, unit: metric.unit, compact: true) + " " + tr("N-1", "LY"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
                .lineLimit(1)
            } else {
                Text(tr("Aucune donnée", "No data")).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    /// Indique les périodes incomplètes (semaine non saisie).
    @ViewBuilder
    private func completenessBadge(_ s: PeriodSummary) -> some View {
        if metric.entries.isEmpty {
            EmptyView()
        } else if s.weeksWithData == 0 {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(Theme.warning)
                .help(tr("Aucune valeur saisie pour cette période", "No value entered for this period"))
        } else if !s.isComplete {
            Text("\(s.weeksWithData)/\(s.weeks.count) " + tr("sem.", "wks"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.warning)
                .help(tr("Certaines semaines de la période ne sont pas saisies", "Some weeks of the period are missing"))
        }
    }

    private var periodShort: String {
        switch period {
        case .pwk: return L10n.weekShort(reference)
        case .l4w: return "L4W"
        case .qtd: return "QTD"
        case .ytd: return "YTD"
        }
    }
}

/// Graphique hebdomadaire d'un résultat (courbe, barres ou comparaison N / N-1).
struct MetricChart: View {
    let points: [SeriesPoint]
    let style: DisplayStyle
    let color: Color
    let compact: Bool
    let calendar: FiscalCalendar

    private var values: [Double] {
        points.compactMap(\.value) + (style == .versusLastYear ? points.compactMap(\.lastYear) : [])
    }

    var body: some View {
        if values.isEmpty {
            Text(tr("Pas encore de données à afficher", "No data to show yet"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if style == .bars {
            barChart
        } else {
            lineChart
        }
    }

    private var domain: ClosedRange<Double> {
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        if style == .bars {
            let low = min(0, lo)
            let high = max(0, hi)
            return low...(high == low ? low + 1 : high + (high - low) * 0.05)
        }
        let pad = hi > lo ? (hi - lo) * 0.15 : max(abs(hi) * 0.1, 1)
        return (lo - pad)...(hi + pad)
    }

    private var axisPositions: [Int] {
        let n = points.count
        guard n > 1 else { return [0] }
        let step = max(1, Int((Double(n) / 6).rounded(.up)))
        return Array(stride(from: 0, to: n, by: step))
    }

    private func label(_ position: Int) -> String {
        guard position >= 0, position < points.count else { return "" }
        let w = points[position].week
        return "\(tr("S", "W"))\(w.index)"
    }

    private var lineChart: some View {
        let base = domain.lowerBound
        return Chart {
            ForEach(points) { p in
                if let v = p.value {
                    AreaMark(x: .value("Semaine", p.position),
                             yStart: .value("Base", base),
                             yEnd: .value("Valeur", v))
                        .foregroundStyle(LinearGradient(colors: [color.opacity(compact ? 0.28 : 0.22), color.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Semaine", p.position), y: .value("Valeur", v), series: .value("Série", "N"))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: compact ? 2 : 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                    if !compact || p.position == points.count - 1 {
                        PointMark(x: .value("Semaine", p.position), y: .value("Valeur", v))
                            .foregroundStyle(color)
                            .symbolSize(compact ? 30 : 24)
                    }
                }
                if style == .versusLastYear, let ly = p.lastYear {
                    LineMark(x: .value("Semaine", p.position), y: .value("Valeur", ly), series: .value("Série", "N-1"))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.monotone)
                }
            }
        }
        .chartYScale(domain: domain)
        .chartXScale(domain: 0...max(1, points.count - 1))
        .chartLegend(.hidden)
        .modifier(AxesModifier(compact: compact, positions: axisPositions, label: label))
    }

    private var barChart: some View {
        let last = points.last(where: { $0.value != nil })?.position
        return Chart {
            ForEach(points) { p in
                if let v = p.value {
                    BarMark(x: .value("Semaine", String(p.position)), y: .value("Valeur", v), width: .ratio(0.62))
                        .foregroundStyle(color.opacity(p.position == last ? 1 : 0.45))
                        .cornerRadius(3)
                } else {
                    BarMark(x: .value("Semaine", String(p.position)), y: .value("Valeur", 0), width: .ratio(0.62))
                        .foregroundStyle(.clear)
                }
            }
        }
        .chartYScale(domain: domain)
        .chartLegend(.hidden)
        .modifier(BarAxesModifier(compact: compact, positions: axisPositions.map(String.init), label: { Int($0).map(label) ?? "" }))
    }
}

/// Axes masqués sur les tuiles, visibles dans la vue détaillée.
private struct AxesModifier: ViewModifier {
    let compact: Bool
    let positions: [Int]
    let label: (Int) -> String

    @ViewBuilder
    func body(content: Content) -> some View {
        if compact {
            content
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
        } else {
            content
                .chartXAxis {
                    AxisMarks(values: positions) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let i = value.as(Int.self) { Text(label(i)) }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(NumberFormat.value(v)) }
                        }
                    }
                }
        }
    }
}

private struct BarAxesModifier: ViewModifier {
    let compact: Bool
    let positions: [String]
    let label: (String) -> String

    @ViewBuilder
    func body(content: Content) -> some View {
        if compact {
            content
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
        } else {
            content
                .chartXAxis {
                    AxisMarks(values: positions) { value in
                        AxisValueLabel {
                            if let s = value.as(String.self) { Text(label(s)) }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(NumberFormat.value(v)) }
                        }
                    }
                }
        }
    }
}
#endif
