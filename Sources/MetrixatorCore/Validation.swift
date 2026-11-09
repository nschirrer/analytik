import Foundation

/// Erreurs métier présentées à l'utilisateur.
public enum MetrixError: Error, Equatable, LocalizedError, Sendable {
    case emptyName
    case duplicateName(String)
    case invalidValue
    case invalidYoY
    case duplicateEntry(Day)
    case incompleteWeek
    case metricNotFound
    case entryNotFound

    public var errorDescription: String? { message }

    public var message: String {
        switch self {
        case .emptyName:
            return L10n.tr("Donnez un titre au résultat.", "Give the result a title.")
        case .duplicateName(let name):
            return L10n.tr("Un résultat nommé « \(name) » existe déjà.", "A result named “\(name)” already exists.")
        case .invalidValue:
            return L10n.tr("Valeur incorrecte : saisissez un nombre (ex. 12 345,5).", "Invalid value: enter a number (e.g. 12,345.5).")
        case .invalidYoY:
            return L10n.tr("Y/Y incorrect : saisissez un pourcentage supérieur à −100 (ex. 4,5).", "Invalid Y/Y: enter a percentage above −100 (e.g. 4.5).")
        case .duplicateEntry(let d):
            return L10n.tr("Une valeur existe déjà pour la semaine du \(L10n.date(d)). Modifiez-la dans l'historique.",
                           "A value already exists for the week of \(L10n.date(d)). Edit it in the history.")
        case .incompleteWeek:
            return L10n.tr("Cette semaine n'est pas encore terminée : la plus petite période suivie est une semaine complète.",
                           "This week isn't over yet: the smallest tracked period is a full week.")
        case .metricNotFound:
            return L10n.tr("Résultat introuvable.", "Result not found.")
        case .entryNotFound:
            return L10n.tr("Valeur introuvable.", "Value not found.")
        }
    }
}

/// Résultat de la vérification d'une saisie (pour afficher un symbole d'alerte à côté du champ fautif).
public struct EntryValidation: Equatable, Sendable {
    public var value: Double?
    public var manualYoY: Double?
    public var valueError: MetrixError?
    public var yoyError: MetrixError?
    public var weekError: MetrixError?

    public var isValid: Bool { valueError == nil && yoyError == nil && weekError == nil && value != nil }
    public var errors: [MetrixError] { [weekError, valueError, yoyError].compactMap { $0 } }
}

public enum Validator {
    /// Vérifie une saisie de semaine. `excludingExisting` = vrai lors d'une modification de la valeur existante.
    public static func validateEntry(valueText: String, yoyText: String, metric: Metric, week: FiscalWeek,
                                     today: Day, isEditingExisting: Bool = false) -> EntryValidation {
        var result = EntryValidation()

        let trimmed = valueText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            if let v = NumberFormat.parse(trimmed) { result.value = v } else { result.valueError = .invalidValue }
        }

        let yoyTrimmed = yoyText.trimmingCharacters(in: .whitespaces)
        if !yoyTrimmed.isEmpty {
            if let y = NumberFormat.parse(yoyTrimmed), metric.kind.comparesInPoints || y > -100 {
                result.manualYoY = y
            } else {
                result.yoyError = .invalidYoY
            }
        }

        if week.end >= today {
            result.weekError = .incompleteWeek
        } else if !isEditingExisting, metric.entry(for: week.start) != nil {
            result.weekError = .duplicateEntry(week.start)
        }
        return result
    }

    public static func validateName(_ name: String, among metrics: [Metric], excluding id: UUID? = nil) -> MetrixError? {
        let normalized = Metric.normalize(name)
        if normalized.isEmpty { return .emptyName }
        if metrics.contains(where: { $0.id != id && $0.normalizedName == normalized }) {
            return .duplicateName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
