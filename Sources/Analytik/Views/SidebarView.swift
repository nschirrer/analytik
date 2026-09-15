import SwiftUI
import AnalytikCore

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var listSelection: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            if model.reports.isEmpty {
                ContentUnavailableView {
                    Label("Aucun rapport", systemImage: "doc.badge.plus")
                } description: {
                    Text("Glissez vos exports GOLD (.xlsx) dans la fenêtre ou utilisez Fichier › Importer (⌘O).")
                }
            } else {
                List(selection: $listSelection) {
                    ForEach(model.reports) { report in
                        ReportRowView(report: report)
                            .tag(report.id)
                            .contextMenu {
                                Button("Retirer", role: .destructive) {
                                    model.removeReports([report.id])
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
                .onDeleteCommand {
                    model.removeReports(listSelection)
                    listSelection = []
                }
            }
            Divider()
            HStack {
                Button {
                    model.importFromPanel()
                } label: {
                    Label("Importer…", systemImage: "plus")
                }
                if model.isImporting {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                if !model.reports.isEmpty {
                    Text(includedSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .navigationTitle("Rapports")
    }

    private var includedSummary: String {
        "\(model.selectedReportIDs.count) sur \(model.reports.count) inclus"
    }
}

struct ReportRowView: View {
    @Environment(AppModel.self) private var model
    let report: Report

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle("Inclure", isOn: inclusionBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help("Inclure ce rapport dans l'analyse")
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(report.dimension)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                    Text(periodsSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var inclusionBinding: Binding<Bool> {
        Binding(
            get: { model.isReportIncluded(report.id) },
            set: { model.setReport(report.id, included: $0) }
        )
    }

    private var title: String {
        report.product.isEmpty ? report.fileName : report.product
    }

    private var subtitle: String {
        var parts = [report.store, report.channel, report.country].filter { !$0.isEmpty }
        if parts.isEmpty { parts = [report.fileName] }
        return parts.joined(separator: " · ")
    }

    private var periodsSummary: String {
        let weeks = report.periods(of: .week).count
        let quarters = report.periods(of: .quarter).count
        var parts: [String] = []
        if weeks > 0 { parts.append("\(weeks) sem.") }
        if quarters > 0 { parts.append("\(quarters) trim.") }
        if parts.isEmpty { parts.append("\(report.periods.count) périodes") }
        return parts.joined(separator: " · ")
    }
}
