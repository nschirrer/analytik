import Foundation

/// Un tour de conversation (« user » ou « assistant »).
public struct ChatTurn: Hashable, Sendable {
    public var role: String
    public var text: String

    public init(role: String, text: String) {
        self.role = role
        self.text = text
    }
}

public struct ClaudeConfig: Sendable {
    public static let defaultModel = "claude-opus-5"
    public static let availableModels = ["claude-opus-5", "claude-sonnet-5", "claude-fable-5-1"]
    public static let apiVersion = "2023-06-01"
    public static let fallbackBeta = "server-side-fallback-2026-07-01"

    public var apiKey: String
    public var model: String
    public var maxTokens: Int
    /// Active les modèles de repli côté serveur (`fallbacks: "default"`).
    public var useFallbacks: Bool
    public var endpoint: URL

    public init(
        apiKey: String,
        model: String = ClaudeConfig.defaultModel,
        maxTokens: Int = 64000,
        useFallbacks: Bool = true,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
        self.useFallbacks = useFallbacks
        self.endpoint = endpoint
    }
}

/// Le prompt système de l'analyste.
public enum ClaudePrompts {
    public static let role = """
    Vous êtes l'analyste des ventes d'un Apple Store en France. L'utilisateur est le responsable du magasin ; il vous interroge sur des exports « GOLD » (unités vendues) qu'il a chargés dans l'app Analytik.

    Règles :
    - Répondez en français, de façon concise et structurée, en citant les chiffres exacts des données (unités, pourcentages).
    - NBL = unités facturées nettes de l'année en cours ; LY = même période l'année précédente ; y/y = NBL/LY − 1 ; Mix = part du membre dans le TOTAL.
    - Les colonnes de semaines (W1…W13) sont des semaines fiscales Apple ; les colonnes de trimestre sont des totaux : ne les additionnez jamais aux semaines.
    - Recalculez les ratios à partir des sommes (jamais de moyenne de pourcentages). Signalez quand une valeur est indisponible (« - »).
    - Si une question est ambiguë ou porte sur des données absentes, dites-le clairement plutôt que d'inventer.
    - Formulez vos réponses comme un compte-rendu d'analyse : constat chiffré, écarts notables, hypothèses prudentes, pistes d'action éventuelles.

    Les données suivent ci-dessous.
    """
}

/// Construit les requêtes HTTP vers l'API Messages.
public enum ClaudeRequestBuilder {
    public static func body(config: ClaudeConfig, rolePrompt: String, dataset: String, turns: [ChatTurn]) throws -> Data {
        var payload: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "stream": true,
            "system": [
                ["type": "text", "text": rolePrompt],
                ["type": "text", "text": dataset, "cache_control": ["type": "ephemeral"]],
            ],
            "messages": normalizedTurns(turns).map { ["role": $0.role, "content": $0.text] },
        ]
        if config.useFallbacks {
            payload["fallbacks"] = "default"
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    public static func request(config: ClaudeConfig, body: Data) -> URLRequest {
        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("text/event-stream", forHTTPHeaderField: "accept")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(ClaudeConfig.apiVersion, forHTTPHeaderField: "anthropic-version")
        if config.useFallbacks {
            request.setValue(ClaudeConfig.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
        return request
    }

    /// Requête de vérification de la clé : `GET /v1/models?limit=1`.
    public static func modelsRequest(config: ClaudeConfig) -> URLRequest {
        var components = URLComponents(url: config.endpoint, resolvingAgainstBaseURL: false)
        components?.path = "/v1/models"
        components?.queryItems = [URLQueryItem(name: "limit", value: "1")]
        var request = URLRequest(url: components?.url ?? config.endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(ClaudeConfig.apiVersion, forHTTPHeaderField: "anthropic-version")
        return request
    }

    /// Supprime les tours vides et garantit l'alternance user/assistant en commençant par « user ».
    static func normalizedTurns(_ turns: [ChatTurn]) -> [ChatTurn] {
        var result: [ChatTurn] = []
        for turn in turns {
            let text = turn.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let role = turn.role == "assistant" ? "assistant" : "user"
            if result.isEmpty && role == "assistant" { continue }
            if let last = result.last, last.role == role {
                result[result.count - 1].text += "\n\n" + text
            } else {
                result.append(ChatTurn(role: role, text: text))
            }
        }
        if result.last?.role == "assistant" {
            result.removeLast()
        }
        return result
    }
}
