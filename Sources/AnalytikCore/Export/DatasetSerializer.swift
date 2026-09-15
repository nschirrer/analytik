import Foundation

/// Sérialise les rapports chargés en texte compact et déterministe pour le prompt système de Claude.
///
/// Le résultat est identique d'un appel à l'autre pour les mêmes rapports, ce qui permet
/// la mise en cache du prompt côté API.
public enum DatasetSerializer {
    public static let legend = """
    Légende des données :
    - NBL = unités facturées nettes (Net Billings) de l'année fiscale en cours.
    - LY = unités de la même période l'année précédente (Last Year).
    - y/y = variation NBL/LY − 1, exprimée en ratio (0.47 = +47 %).
    - Mix = part du membre dans le TOTAL (0.65 = 65 %).
    - Les colonnes « FYxx Qn Wk » sont des semaines fiscales Apple ; les colonnes « FYxx Qn » sont des totaux de trimestre : ne jamais les additionner aux semaines.
    - « - » signifie non disponible. Le séparateur décimal est le point.
    - Chaque rapport correspond à un fichier (un produit, un magasin, un canal) ; la première colonne de son tableau est la dimension en lignes.
    """

    public static func serialize(reports: [Report]) -> String {
        let ordered = reports.sorted { lhs, rhs in
            if lhs.fileName != rhs.fileName { return lhs.fileName < rhs.fileName }
            return lhs.sheetName < rhs.sheetName
        }
        var parts: [String] = [legend]
        for report in ordered {
            parts.append(serialize(report))
        }
        return parts.joined(separator: "\n\n")
    }

    public static func serialize(_ report: Report) -> String {
        var lines: [String] = []
        lines.append("## Rapport : \(report.fileName) (feuille « \(report.sheetName) »)")
        var metadata: [String] = []
        for key in report.metadataOrder {
            if let value = report.metadata[key], !value.isEmpty {
                metadata.append("\(key) : \(value)")
            }
        }
        metadata.append("Dimension des lignes : \(report.dimension)")
        lines.append(metadata.joined(separator: " | "))
        lines.append(([report.dimension, "Métrique"] + report.periods.map { $0.label }).joined(separator: ";"))
        for member in report.members {
            for metric in report.metrics {
                var fields = [member, metric]
                for period in report.periods {
                    if let value = report.value(member: member, metric: metric, period: period) {
                        fields.append(NumberText.plain(value))
                    } else {
                        fields.append("-")
                    }
                }
                lines.append(fields.joined(separator: ";"))
            }
        }
        return lines.joined(separator: "\n")
    }
}
