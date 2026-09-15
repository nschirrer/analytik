import SwiftUI
import AnalytikCore

struct AnalysisView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.selectedReports.isEmpty {
                ContentUnavailableView(
                    "Aucune donnée à analyser",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Importez un export GOLD et cochez-le dans la barre latérale.")
                )
            } else {
                ControlBar()
                Divider()
                content
                Divider()
                StatusBar()
            }
        }
        .navigationTitle("Analyse")
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewMode {
        case .table:
            PivotTableView(table: model.pivotTable)
        case .chart:
            ChartContainerView()
        case .comparison:
            ComparisonView()
        }
    }
}

struct ControlBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 14) {
            Picker("Affichage", selection: $model.viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)

            Picker("Métrique", selection: $model.metric) {
                ForEach(Metric.allCases, id: \.self) { metric in
                    Text(metric.frenchName).tag(metric)
                }
            }
            .frame(maxWidth: 260)

            Picker("Lignes", selection: $model.series) {
                ForEach(SeriesDimension.allCases, id: \.self) { dimension in
                    Text(dimension == .member ? model.memberDimensionTitle : dimension.frenchName).tag(dimension)
                }
            }
            .frame(maxWidth: 240)

            Picker("Périodes", selection: $model.granularity) {
                ForEach(Granularity.allCases, id: \.self) { granularity in
                    Text(granularity.frenchName).tag(granularity)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 190)

            Spacer(minLength: 0)

            PeriodFilterButton()
            SeriesFilterButton()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct StatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Text(model.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.hasMixedDimensions && model.series == .member {
                Label("Les rapports cochés n'ont pas la même dimension en lignes : choisissez « Produit » ou « Fichier » comme lignes.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
            Spacer()
            Button("Exporter CSV…") {
                model.exportCSV()
            }
            .controlSize(.small)
            .disabled(model.pivotTable.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct PeriodFilterButton: View {
    @Environment(AppModel.self) private var model
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label(title, systemImage: "calendar")
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            PeriodFilterPopover()
        }
    }

    private var title: String {
        let hidden = model.excludedPeriodIDs.count
        return hidden == 0 ? "Périodes" : "Périodes (\(hidden) masquée\(hidden > 1 ? "s" : ""))"
    }
}

struct PeriodFilterPopover: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Périodes affichées")
                .font(.headline)
            HStack {
                Button("Toutes") { model.excludedPeriodIDs = [] }
                Button("Aucune") { model.excludedPeriodIDs = Set(model.availablePeriods.map { $0.id }) }
            }
            .controlSize(.small)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.availablePeriods) { period in
                        Toggle(period.label, isOn: binding(for: period.id))
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding()
        .frame(width: 260)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { model.isPeriodShown(id) },
            set: { model.setPeriod(id, shown: $0) }
        )
    }
}

struct SeriesFilterButton: View {
    @Environment(AppModel.self) private var model
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label(title, systemImage: "line.3.horizontal.decrease.circle")
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SeriesFilterPopover()
        }
    }

    private var title: String {
        let hidden = model.excludedSeriesIDs.count
        return hidden == 0 ? "Lignes" : "Lignes (\(hidden) masquée\(hidden > 1 ? "s" : ""))"
    }
}

struct SeriesFilterPopover: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 8) {
            Text("Lignes affichées")
                .font(.headline)
            HStack {
                Button("Toutes") { model.excludedSeriesIDs = [] }
                Button("Aucune") { model.excludedSeriesIDs = Set(model.availableSeries.map { $0.id }) }
            }
            .controlSize(.small)
            if model.series == .member {
                Toggle("Inclure la ligne TOTAL", isOn: $model.includeTotalMember)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.availableSeries) { option in
                        Toggle(option.label, isOn: binding(for: option.id))
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding()
        .frame(width: 300)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { model.isSeriesShown(id) },
            set: { model.setSeries(id, shown: $0) }
        )
    }
}
