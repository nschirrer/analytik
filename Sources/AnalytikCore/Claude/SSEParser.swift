import Foundation

/// Un événement Server-Sent Events brut.
public struct SSEEvent: Equatable, Sendable {
    public var event: String?
    public var data: String

    public init(event: String?, data: String) {
        self.event = event
        self.data = data
    }
}

/// Analyseur SSE ligne à ligne (les lignes sont fournies sans leur fin de ligne).
public struct SSEParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []

    public init() {}

    /// Alimente une ligne ; renvoie un événement quand une ligne vide termine un bloc.
    public mutating func feed(line: String) -> SSEEvent? {
        if line.isEmpty { return flush() }
        if line.hasPrefix(":") { return nil }
        let (field, value) = SSEParser.split(line)
        switch field {
        case "event": eventName = value
        case "data": dataLines.append(value)
        default: break
        }
        return nil
    }

    /// Termine le bloc en cours (utile en fin de flux sans ligne vide finale).
    public mutating func flush() -> SSEEvent? {
        defer {
            eventName = nil
            dataLines = []
        }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(event: eventName, data: dataLines.joined(separator: "\n"))
    }

    static func split(_ line: String) -> (String, String) {
        guard let colon = line.firstIndex(of: ":") else { return (line, "") }
        let field = String(line[..<colon])
        var value = String(line[line.index(after: colon)...])
        if value.hasPrefix(" ") { value.removeFirst() }
        return (field, value)
    }
}

/// Les événements utiles du flux de l'API Messages.
public enum ClaudeStreamEvent: Equatable, Sendable {
    case messageStart(model: String, cacheRead: Int, cacheCreation: Int)
    case textDelta(String)
    case fallback(from: String, to: String)
    case stop(reason: String, category: String?)
    case done
}

public enum ClaudeEventDecoder {
    /// Décode un événement SSE ; renvoie nil pour les événements ignorés, lève une erreur pour `error`.
    public static func decode(_ event: SSEEvent) throws -> ClaudeStreamEvent? {
        guard let data = event.data.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let type = (object["type"] as? String) ?? event.event ?? ""
        switch type {
        case "message_start":
            let message = object["message"] as? [String: Any] ?? [:]
            let usage = message["usage"] as? [String: Any] ?? [:]
            return .messageStart(
                model: message["model"] as? String ?? "",
                cacheRead: usage["cache_read_input_tokens"] as? Int ?? 0,
                cacheCreation: usage["cache_creation_input_tokens"] as? Int ?? 0
            )
        case "content_block_start":
            let block = object["content_block"] as? [String: Any] ?? [:]
            guard block["type"] as? String == "fallback" else { return nil }
            let from = (block["from"] as? [String: Any])?["model"] as? String ?? ""
            let to = (block["to"] as? [String: Any])?["model"] as? String ?? ""
            return .fallback(from: from, to: to)
        case "content_block_delta":
            let delta = object["delta"] as? [String: Any] ?? [:]
            guard delta["type"] as? String == "text_delta", let text = delta["text"] as? String else { return nil }
            return .textDelta(text)
        case "message_delta":
            let delta = object["delta"] as? [String: Any] ?? [:]
            guard let reason = delta["stop_reason"] as? String else { return nil }
            let details = (delta["stop_details"] as? [String: Any]) ?? (object["stop_details"] as? [String: Any])
            return .stop(reason: reason, category: details?["category"] as? String)
        case "message_stop":
            return .done
        case "error":
            let error = object["error"] as? [String: Any] ?? [:]
            throw ClaudeError.streamError(
                type: error["type"] as? String ?? "error",
                message: error["message"] as? String ?? "erreur inconnue"
            )
        default:
            return nil
        }
    }
}
