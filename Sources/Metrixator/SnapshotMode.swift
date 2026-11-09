#if os(macOS)
import AppKit
import MetrixatorCore
import SwiftUI

/// Mode « capture d'écran » pour la vérification automatique (CI) :
/// `Metrixator --snapshot <dossier>` lance l'app sur un fichier de données temporaire
/// rempli avec les données d'exemple, parcourt les écrans, enregistre une image PNG
/// de chacun, puis quitte. Les données de l'utilisateur ne sont jamais touchées.
struct SnapshotMode {
    let outputDirectory: URL
    let dataURL: URL

    static func fromArguments(_ args: [String] = CommandLine.arguments) -> SnapshotMode? {
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        let out = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let data = FileManager.default.temporaryDirectory
            .appendingPathComponent("metrixator-snapshot-\(UUID().uuidString)")
            .appendingPathComponent("metrixator.json")
        return SnapshotMode(outputDirectory: out, dataURL: data)
    }

    @MainActor
    func run() async {
        await pause(2.5)
        guard let store = AppEnvironment.store, let router = AppEnvironment.router,
              let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else {
            print("snapshot: fenêtre introuvable")
            NSApp.terminate(nil)
            return
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        window.setFrame(NSRect(x: 40, y: 40, width: 1440, height: 920), display: true)
        L10n.current = .fr
        store.updateSettings(AppSettings(calendar: .standard, period: .pwk, language: .fr))
        let revenue = store.metrics.first!.id

        await shot(window, "01-tableau-pwk") { router.section = .dashboard }
        await shot(window, "02-tableau-qtd") { store.setPeriod(.qtd) }
        await shot(window, "03-tableau-ytd") { store.setPeriod(.ytd) }
        store.setPeriod(.pwk)
        await shot(window, "04-detail") { router.path = [revenue] }
        await shot(window, "05-liste") {
            router.path = []
            router.section = .list
        }
        await shot(window, "06-editeur") {
            router.section = .dashboard
            router.editor = EditorRequest(metricID: store.metrics[1].id)
        }
        router.editor = nil
        await pause(0.8)
        await shot(window, "07-nouveau-resultat") { router.editor = EditorRequest(metricID: nil) }
        router.editor = nil
        await pause(0.8)
        await shot(window, "08-saisie-semaine") { router.showWeeklyEntry = true }
        router.showWeeklyEntry = false
        await pause(0.8)

        // Suppression puis bannière d'annulation.
        await shot(window, "09-suppression-annulable") {
            store.deleteMetric(revenue)
            router.toast = store.undoLabel
        }
        store.undo()
        router.toast = nil

        NSApp.appearance = NSAppearance(named: .darkAqua)
        await shot(window, "10-tableau-sombre") { router.section = .dashboard }
        await shot(window, "11-detail-sombre") { router.path = [store.metrics[3].id] }
        NSApp.appearance = NSAppearance(named: .aqua)

        await shot(window, "12-dashboard-english") {
            router.path = []
            L10n.apply(.en)
            store.updateSettings(AppSettings(calendar: .standard, period: .pwk, language: .en))
        }

        // Écran vide.
        await shot(window, "13-tableau-vide") {
            L10n.apply(.fr)
            store.updateSettings(AppSettings(calendar: .standard, period: .pwk, language: .fr))
            store.eraseAll()
        }

        print("snapshot: terminé → \(outputDirectory.path)")
        NSApp.terminate(nil)
    }

    @MainActor
    private func shot(_ window: NSWindow, _ name: String, _ action: () -> Void) async {
        action()
        await pause(1.5)
        let target = window.attachedSheet ?? window
        save(capture(window), name)
        if target !== window { save(capture(target), name + "-feuille") }
    }

    @MainActor
    private func capture(_ window: NSWindow) -> NSBitmapImageRep? {
        guard let view = window.contentView?.superview ?? window.contentView else { return nil }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    private func save(_ rep: NSBitmapImageRep?, _ name: String) {
        guard let data = rep?.representation(using: .png, properties: [:]) else {
            print("snapshot: échec \(name)")
            return
        }
        let url = outputDirectory.appendingPathComponent(name + ".png")
        try? data.write(to: url)
        print("snapshot: \(url.lastPathComponent)")
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
#endif
