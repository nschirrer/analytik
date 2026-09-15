import Foundation
import CoreXLSX

/// Une feuille de calcul sous forme de grille dense de textes (`rows[ligne][colonne]`, indices à partir de 0).
public struct SheetGrid: Sendable {
    public var name: String
    public var rows: [[String?]]

    public init(name: String, rows: [[String?]]) {
        self.name = name
        self.rows = rows
    }

    public func cell(_ row: Int, _ column: Int) -> String? {
        guard row >= 0, row < rows.count, column >= 0, column < rows[row].count else { return nil }
        return rows[row][column]
    }
}

public enum XLSXReadError: Error, LocalizedError, Equatable {
    case cannotOpen(String)
    case noWorksheet(String)

    public var errorDescription: String? {
        switch self {
        case let .cannotOpen(name):
            return "Impossible d'ouvrir « \(name) » : ce n'est pas un classeur .xlsx valide."
        case let .noWorksheet(name):
            return "Le classeur « \(name) » ne contient aucune feuille."
        }
    }
}

/// Lit un classeur .xlsx avec CoreXLSX et renvoie chaque feuille sous forme de grille de textes.
public enum XLSXGridReader {
    public static func readSheets(atPath path: String) throws -> [SheetGrid] {
        let displayName = (path as NSString).lastPathComponent
        guard let file = XLSXFile(filepath: path) else {
            throw XLSXReadError.cannotOpen(displayName)
        }
        let shared = try file.parseSharedStrings()
        var grids: [SheetGrid] = []
        for workbook in try file.parseWorkbooks() {
            for (name, worksheetPath) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let worksheet = try file.parseWorksheet(at: worksheetPath)
                let sheetName = name ?? "Feuille \(grids.count + 1)"
                grids.append(makeGrid(worksheet, name: sheetName, shared: shared))
            }
        }
        if grids.isEmpty {
            throw XLSXReadError.noWorksheet(displayName)
        }
        return grids
    }

    /// Texte d'une cellule : chaîne partagée (simple ou enrichie), chaîne en ligne, ou valeur brute.
    static func text(of cell: Cell, shared: SharedStrings?) -> String? {
        switch cell.type {
        case .some(.sharedString):
            guard let shared = shared,
                  let index = cell.value.flatMap({ Int($0) }),
                  index >= 0, index < shared.items.count else { return nil }
            let item = shared.items[index]
            if let plain = item.text { return plain }
            let rich = item.richText.compactMap { $0.text }.joined()
            return rich.isEmpty ? nil : rich
        case .some(.inlineStr):
            return cell.inlineString?.text
        default:
            return cell.value
        }
    }

    /// « A » → 0, « Z » → 25, « AA » → 26.
    static func columnIndex(_ reference: ColumnReference) -> Int {
        var number = 0
        for scalar in reference.value.uppercased().unicodeScalars {
            let v = Int(scalar.value)
            guard v >= 65, v <= 90 else { continue }
            number = number * 26 + (v - 64)
        }
        return number - 1
    }

    static func makeGrid(_ worksheet: Worksheet, name: String, shared: SharedStrings?) -> SheetGrid {
        var sparse: [Int: [Int: String]] = [:]
        var maxRow = -1
        var maxColumn = -1
        for row in worksheet.data?.rows ?? [] {
            for cell in row.cells {
                let r = Int(cell.reference.row) - 1
                let c = columnIndex(cell.reference.column)
                guard r >= 0, c >= 0, let value = text(of: cell, shared: shared) else { continue }
                sparse[r, default: [:]][c] = value
                maxRow = max(maxRow, r)
                maxColumn = max(maxColumn, c)
            }
        }
        var rows: [[String?]] = Array(
            repeating: [String?](repeating: nil, count: maxColumn + 1),
            count: maxRow + 1
        )
        for (r, columns) in sparse {
            for (c, value) in columns {
                rows[r][c] = value
            }
        }
        return SheetGrid(name: name, rows: rows)
    }
}
