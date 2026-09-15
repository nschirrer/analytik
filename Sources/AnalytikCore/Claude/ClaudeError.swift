import Foundation

/// Erreurs de l'intégration Claude, avec des messages en français prêts à afficher.
public enum ClaudeError: Error, LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case billing(String)
    case permission(String)
    case notFound(String)
    case rateLimited(retryAfter: Int?)
    case badRequest(String)
    case tooLarge
    case overloaded
    case server(Int, String)
    case http(Int, String)
    case streamError(type: String, message: String)
    case network(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Aucune clé API Anthropic n'est configurée. Ouvrez les réglages (⌘,) pour en ajouter une."
        case .invalidAPIKey:
            return "Clé API invalide ou révoquée (401). Vérifiez-la dans les réglages."
        case let .billing(message):
            return "Problème de facturation sur le compte Anthropic (402) : \(message)"
        case let .permission(message):
            return "Accès refusé par l'API (403) : \(message)"
        case let .notFound(message):
            return "Ressource introuvable (404) : \(message)"
        case let .rateLimited(retryAfter):
            if let seconds = retryAfter {
                return "Limite de requêtes atteinte (429). Réessayez dans \(seconds) s."
            }
            return "Limite de requêtes atteinte (429). Réessayez dans quelques instants."
        case let .badRequest(message):
            return "Requête refusée par l'API (400) : \(message)"
        case .tooLarge:
            return "La requête est trop volumineuse (413). Décochez des rapports pour réduire les données envoyées."
        case .overloaded:
            return "Le service Anthropic est surchargé (529). Réessayez dans quelques instants."
        case let .server(status, message):
            return "Erreur du service Anthropic (\(status)) : \(message)"
        case let .http(status, message):
            return "Réponse inattendue de l'API (\(status)) : \(message)"
        case let .streamError(type, message):
            return "Erreur pendant la réponse (\(type)) : \(message)"
        case let .network(message):
            return "Connexion impossible : \(message)"
        case .invalidResponse:
            return "Réponse invalide de l'API."
        }
    }

    static func fromStatus(_ status: Int, message: String, retryAfter: Int?) -> ClaudeError {
        switch status {
        case 400: return .badRequest(message)
        case 401: return .invalidAPIKey
        case 402: return .billing(message)
        case 403: return .permission(message)
        case 404: return .notFound(message)
        case 413: return .tooLarge
        case 429: return .rateLimited(retryAfter: retryAfter)
        case 529: return .overloaded
        case 500...599: return .server(status, message)
        default: return .http(status, message)
        }
    }
}
