import XCTest
@testable import AnalytikCore

final class ClaudeRequestTests: XCTestCase {
    private func payload(_ config: ClaudeConfig, turns: [ChatTurn]) throws -> [String: Any] {
        let data = try ClaudeRequestBuilder.body(config: config, rolePrompt: "rôle", dataset: "données", turns: turns)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testBodyShape() throws {
        let config = ClaudeConfig(apiKey: "sk-test")
        let body = try payload(config, turns: [ChatTurn(role: "user", text: "Bonjour")])
        XCTAssertEqual(body["model"] as? String, "claude-opus-5")
        XCTAssertEqual(body["max_tokens"] as? Int, 64000)
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["fallbacks"] as? String, "default")
        XCTAssertNil(body["thinking"])
        let system = try XCTUnwrap(body["system"] as? [[String: Any]])
        XCTAssertEqual(system.count, 2)
        XCTAssertEqual(system[0]["text"] as? String, "rôle")
        XCTAssertEqual(system[1]["text"] as? String, "données")
        let cache = try XCTUnwrap(system[1]["cache_control"] as? [String: Any])
        XCTAssertEqual(cache["type"] as? String, "ephemeral")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        XCTAssertEqual(messages[0]["content"] as? String, "Bonjour")
    }

    func testHeaders() throws {
        let config = ClaudeConfig(apiKey: "sk-test")
        let request = ClaudeRequestBuilder.request(config: config, body: Data())
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "server-side-fallback-2026-07-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

        var noFallback = config
        noFallback.useFallbacks = false
        let plain = ClaudeRequestBuilder.request(config: noFallback, body: Data())
        XCTAssertNil(plain.value(forHTTPHeaderField: "anthropic-beta"))
        let body = try payload(noFallback, turns: [ChatTurn(role: "user", text: "x")])
        XCTAssertNil(body["fallbacks"])

        let models = ClaudeRequestBuilder.modelsRequest(config: config)
        XCTAssertEqual(models.url?.absoluteString, "https://api.anthropic.com/v1/models?limit=1")
        XCTAssertEqual(models.httpMethod, "GET")
    }

    func testTurnsAreNormalized() {
        let turns = [
            ChatTurn(role: "assistant", text: "orphelin"),
            ChatTurn(role: "user", text: "Q1"),
            ChatTurn(role: "assistant", text: ""),
            ChatTurn(role: "user", text: "Q2"),
            ChatTurn(role: "assistant", text: "R2"),
            ChatTurn(role: "user", text: "Q3"),
            ChatTurn(role: "assistant", text: "  "),
        ]
        let normalized = ClaudeRequestBuilder.normalizedTurns(turns)
        XCTAssertEqual(normalized, [
            ChatTurn(role: "user", text: "Q1\n\nQ2"),
            ChatTurn(role: "assistant", text: "R2"),
            ChatTurn(role: "user", text: "Q3"),
        ])
    }

    func testErrorMessageExtraction() {
        let json = Data(#"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#.utf8)
        XCTAssertEqual(ClaudeClient.errorMessage(from: json), "invalid x-api-key")
        XCTAssertEqual(ClaudeClient.errorMessage(from: Data("plain".utf8)), "plain")
        XCTAssertEqual(ClaudeClient.errorMessage(from: Data()), "aucun détail")
        XCTAssertEqual(ClaudeError.fromStatus(401, message: "", retryAfter: nil), .invalidAPIKey)
        XCTAssertEqual(ClaudeError.fromStatus(429, message: "", retryAfter: 7), .rateLimited(retryAfter: 7))
        XCTAssertEqual(ClaudeError.fromStatus(503, message: "down", retryAfter: nil), .server(503, "down"))
    }
}
