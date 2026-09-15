import SwiftUI
import AnalytikCore

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 420)
        } detail: {
            AnalysisView()
        }
        .inspector(isPresented: $model.isClaudePanelShown) {
            ClaudePanelView()
                .inspectorColumnWidth(min: 340, ideal: 440, max: 700)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.isClaudePanelShown.toggle()
                } label: {
                    Label("Claude", systemImage: "sparkles")
                }
                .help("Afficher ou masquer le panneau d'analyse Claude (⌥⌘C)")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.importFiles(urls)
            return true
        }
        .alert("Import impossible", isPresented: $model.showsImportErrors) {
            Button("OK") {}
        } message: {
            Text(model.importErrors.joined(separator: "\n"))
        }
        .task {
            model.bootstrapIfNeeded()
        }
    }
}
