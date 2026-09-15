import Foundation

/// Client HTTP minimal de l'API Messages d'Anthropic (streaming SSE).
public final class ClaudeClient: @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = ClaudeClient.makeSession()) {
        self.session = session
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 3600
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    /// Envoie la conversation et diffuse les événements de la réponse.
    public func stream(
        config: ClaudeConfig,
        rolePrompt: String,
        dataset: String,
        turns: [ChatTurn]
    ) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.run(config: config, rolePrompt: rolePrompt, dataset: dataset, turns: turns, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Vérifie la clé avec `GET /v1/models` et renvoie l'identifiant du premier modèle disponible.
    public func testConnection(config: ClaudeConfig) async throws -> String {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClaudeError.missingAPIKey
        }
        let request = ClaudeRequestBuilder.modelsRequest(config: config)
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw ClaudeError.network(error.localizedDescription)
        }
        guard let http = result.1 as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let retryAfter = Int(http.value(forHTTPHeaderField: "retry-after") ?? "")
            throw ClaudeError.fromStatus(http.statusCode, message: ClaudeClient.errorMessage(from: result.0), retryAfter: retryAfter)
        }
        let object = (try? JSONSerialization.jsonObject(with: result.0)) as? [String: Any]
        let models = object?["data"] as? [[String: Any]] ?? []
        return models.first?["id"] as? String ?? "modèles accessibles"
    }

    // MARK: Internes

    private func run(
        config: ClaudeConfig,
        rolePrompt: String,
        dataset: String,
        turns: [ChatTurn],
        continuation: AsyncThrowingStream<ClaudeStreamEvent, Error>.Continuation
    ) async throws {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClaudeError.missingAPIKey
        }
        var attemptConfig = config
        var attempt = 0
        while true {
            attempt += 1
            let body = try ClaudeRequestBuilder.body(config: attemptConfig, rolePrompt: rolePrompt, dataset: dataset, turns: turns)
            let request = ClaudeRequestBuilder.request(config: attemptConfig, body: body)

            let result: (URLSession.AsyncBytes, URLResponse)
            do {
                result = try await session.bytes(for: request)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ClaudeError.network(error.localizedDescription)
            }
            let bytes = result.0
            guard let http = result.1 as? HTTPURLResponse else { throw ClaudeError.invalidResponse }

            if !(200..<300).contains(http.statusCode) {
                var data = Data()
                for try await byte in bytes { data.append(byte) }
                let message = ClaudeClient.errorMessage(from: data)
                // Si le serveur ne connaît pas l'en-tête bêta des replis, on réessaie sans.
                if http.statusCode == 400, attemptConfig.useFallbacks, attempt == 1,
                   message.lowercased().contains("anthropic-beta") || message.lowercased().contains("fallbacks") {
                    attemptConfig.useFallbacks = false
                    continue
                }
                let retryAfter = Int(http.value(forHTTPHeaderField: "retry-after") ?? "")
                throw ClaudeError.fromStatus(http.statusCode, message: message, retryAfter: retryAfter)
            }

            var parser = SSEParser()
            for try await line in bytes.lines {
                try Task.checkCancellation()
                if let event = parser.feed(line: line), let decoded = try ClaudeEventDecoder.decode(event) {
                    continuation.yield(decoded)
                }
            }
            if let event = parser.flush(), let decoded = try ClaudeEventDecoder.decode(event) {
                continuation.yield(decoded)
            }
            return
        }
    }

    static func errorMessage(from data: Data) -> String {
        if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "aucun détail" : String(text.prefix(300))
    }
}
