import SwiftUI
import AnalytikCore

@main
struct AnalytikApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Analytik") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1100, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Importer des exports GOLD…") {
                    model.importFromPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
                Button("Exporter le tableau en CSV…") {
                    model.exportCSV()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button(model.isClaudePanelShown ? "Masquer Claude" : "Afficher Claude") {
                    model.isClaudePanelShown.toggle()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
