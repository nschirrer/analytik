#if os(macOS)
import MetrixatorCore
import SwiftUI

struct RootView: View {
    @Environment(MetricStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(selection: $router.section) {
                Label(tr("Tableau de synthèse", "Dashboard"), systemImage: "square.grid.2x2")
                    .tag(Router.Section.dashboard)
                Label(tr("Résultats suivis", "Tracked results"), systemImage: "list.bullet.rectangle")
                    .tag(Router.Section.list)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } detail: {
            NavigationStack(path: $router.path) {
                Group {
                    switch router.section ?? .dashboard {
                    case .dashboard: DashboardView()
                    case .list: MetricListView()
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    MetricDetailView(metricID: id)
                }
            }
        }
        .onChange(of: router.section) {
            router.path.removeAll()
        }
        .sheet(item: $router.editor) { request in
            MetricEditorView(metricID: request.metricID)
                .environment(store)
                .environment(router)
        }
        .sheet(isPresented: $router.showWeeklyEntry) {
            WeeklyEntryView()
                .environment(store)
                .environment(router)
        }
        .overlay(alignment: .bottom) {
            UndoToast()
        }
        .alert(tr("Données", "Data"), isPresented: Binding(get: { store.loadIssue != nil }, set: { if !$0 { store.loadIssue = nil } })) {
            Button("OK") { store.loadIssue = nil }
        } message: {
            Text(store.loadIssue ?? "")
        }
        .background(WindowConfigurator())
        .id(store.settings.language)
    }
}

/// Bannière « … supprimé · Annuler » affichée quelques secondes après une suppression.
struct UndoToast: View {
    @Environment(MetricStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        if let message = router.toast {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                Text(message)
                    .lineLimit(1)
                Button(tr("Annuler", "Undo")) {
                    store.undo()
                    router.toast = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button {
                    router.toast = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: message) {
                try? await Task.sleep(for: .seconds(8))
                if router.toast == message { router.toast = nil }
            }
        }
    }
}
#endif
