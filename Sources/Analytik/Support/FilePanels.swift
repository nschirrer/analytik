import AppKit
import UniformTypeIdentifiers

/// Panneaux d'ouverture et d'enregistrement.
enum FilePanels {
    static var workbookType: UTType {
        UTType(filenameExtension: "xlsx") ?? .spreadsheet
    }

    @MainActor
    static func chooseWorkbooks() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [workbookType]
        panel.message = "Choisissez un ou plusieurs exports GOLD (.xlsx)."
        panel.prompt = "Importer"
        return panel.runModal() == .OK ? panel.urls : []
    }

    @MainActor
    static func chooseCSVDestination(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.message = "Enregistrer le tableau affiché au format CSV (séparateur « ; »)."
        return panel.runModal() == .OK ? panel.url : nil
    }
}
