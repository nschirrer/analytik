#if os(macOS)
import AppKit
import MetrixatorCore
import SwiftUI

/// Raccourci de traduction pour l'interface.
func tr(_ fr: String, _ en: String) -> String { L10n.tr(fr, en) }

/// Références partagées (utilisées par le délégué d'app pour le mode capture d'écran).
@MainActor
enum AppEnvironment {
    static var store: MetricStore!
    static var router: Router!
    static var snapshot: SnapshotMode?
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nécessaire quand l'exécutable est lancé hors d'un paquet .app (swift run, Xcode).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let snapshot = AppEnvironment.snapshot {
            Task { @MainActor in await snapshot.run() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct MetrixatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: MetricStore
    @State private var router = Router()

    init() {
        let snapshot = SnapshotMode.fromArguments()
        let store: MetricStore
        if let snapshot {
            store = MetricStore(fileURL: snapshot.dataURL, seedWithSampleData: true)
        } else {
            store = MetricStore(fileURL: MetricStore.defaultFileURL(), seedWithSampleData: true)
        }
        L10n.apply(store.settings.language)
        _store = State(initialValue: store)
        AppEnvironment.store = store
        AppEnvironment.snapshot = snapshot
    }

    var body: some Scene {
        WindowGroup("Metrixator", id: "main") {
            RootView()
                .environment(store)
                .environment(router)
                .frame(minWidth: 960, minHeight: 620)
                .onAppear { AppEnvironment.router = router }
        }
        .defaultSize(width: 1360, height: 860)
        .commands { AppCommands(store: store, router: router) }

        Settings {
            SettingsView()
                .environment(store)
                .environment(router)
        }
    }
}

/// Menus de l'app.
struct AppCommands: Commands {
    let store: MetricStore
    let router: Router

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(tr("Nouveau résultat…", "New result…")) { router.editor = EditorRequest(metricID: nil) }
                .keyboardShortcut("n")
            Button(tr("Saisir la semaine…", "Enter the week…")) { router.showWeeklyEntry = true }
                .keyboardShortcut("e")
            Divider()
            Button(tr("Importer un CSV…", "Import CSV…")) { CSVPanels.importCSV(store: store) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button(tr("Exporter en CSV…", "Export CSV…")) { CSVPanels.exportCSV(store: store) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        CommandGroup(after: .undoRedo) {
            Button(store.undoLabel.map { tr("Annuler : \($0)", "Undo: \($0)") } ?? tr("Annuler la suppression", "Undo deletion")) {
                store.undo()
                router.toast = nil
            }
            .keyboardShortcut("z", modifiers: [.command, .option])
            .disabled(!store.canUndo)
        }
        CommandMenu(tr("Période", "Period")) {
            Button("PWK — " + PeriodKind.pwk.label) { store.setPeriod(.pwk) }.keyboardShortcut("1")
            Button("L4W — " + PeriodKind.l4w.label) { store.setPeriod(.l4w) }.keyboardShortcut("2")
            Button("QTD — " + PeriodKind.qtd.label) { store.setPeriod(.qtd) }.keyboardShortcut("3")
            Button("YTD — " + PeriodKind.ytd.label) { store.setPeriod(.ytd) }.keyboardShortcut("4")
            Divider()
            Button(tr("Semaine précédente", "Previous week")) { router.weekOffset -= 1 }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button(tr("Semaine suivante", "Next week")) { router.weekOffset = min(0, router.weekOffset + 1) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button(tr("Revenir à la dernière semaine (PWK)", "Back to last week (PWK)")) { router.weekOffset = 0 }
        }
    }
}
#endif
