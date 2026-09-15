import XCTest
@testable import AnalytikCore

final class SSEParserTests: XCTestCase {
    private func run(_ lines: [String]) throws -> [ClaudeStreamEvent] {
        var parser = SSEParser()
        var events: [ClaudeStreamEvent] = []
        for line in lines {
            if let event = parser.feed(line: line), let decoded = try ClaudeEventDecoder.decode(event) {
                events.append(decoded)
            }
        }
        if let event = parser.flush(), let decoded = try ClaudeEventDecoder.decode(event) {
            events.append(decoded)
        }
        return events
    }

    func testTypicalStream() throws {
        let lines = [
            "event: message_start",
            #"data: {"type":"message_start","message":{"id":"msg_1","model":"claude-opus-5","usage":{"input_tokens":10,"cache_read_input_tokens":1234,"cache_creation_input_tokens":0}}}"#,
            "",
            "event: content_block_start",
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#,
            "",
            "event: content_block_delta",
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"hmm"}}"#,
            "",
            ": ping comment",
            "event: ping",
            #"data: {"type":"ping"}"#,
            "",
            "event: content_block_start",
            #"data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}"#,
            "",
            "event: content_block_delta",
            #"data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Bon"}}"#,
            "",
            "event: content_block_delta",
            #"data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"jour"}}"#,
            "",
            "event: content_block_stop",
            #"data: {"type":"content_block_stop","index":1}"#,
            "",
            "event: message_delta",
            #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":12}}"#,
            "",
            "event: message_stop",
            #"data: {"type":"message_stop"}"#,
        ]
        let events = try run(lines)
        XCTAssertEqual(events, [
            .messageStart(model: "claude-opus-5", cacheRead: 1234, cacheCreation: 0),
            .textDelta("Bon"),
            .textDelta("jour"),
            .stop(reason: "end_turn", category: nil),
            .done,
        ])
    }

    func testRefusalAndFallback() throws {
        let lines = [
            "event: content_block_start",
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"fallback","from":{"model":"claude-opus-5"},"to":{"model":"claude-opus-4-8"}}}"#,
            "",
            "event: message_delta",
            #"data: {"type":"message_delta","delta":{"stop_reason":"refusal","stop_details":{"type":"refusal","category":"cyber"}}}"#,
            "",
        ]
        let events = try run(lines)
        XCTAssertEqual(events, [
            .fallback(from: "claude-opus-5", to: "claude-opus-4-8"),
            .stop(reason: "refusal", category: "cyber"),
        ])
    }

    func testErrorEventThrows() {
        let lines = [
            "event: error",
            #"data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#,
            "",
        ]
        XCTAssertThrowsError(try run(lines)) { error in
            XCTAssertEqual(error as? ClaudeError, .streamError(type: "overloaded_error", message: "Overloaded"))
        }
    }

    func testMultiLineDataAndFieldsWithoutSpace() {
        var parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event:custom"))
        XCTAssertNil(parser.feed(line: "data:{\"a\":"))
        XCTAssertNil(parser.feed(line: "data: 1}"))
        XCTAssertNil(parser.feed(line: "id: 42"))
        let event = parser.feed(line: "")
        XCTAssertEqual(event, SSEEvent(event: "custom", data: "{\"a\":\n1}"))
        XCTAssertNil(parser.feed(line: ""))
        XCTAssertNil(parser.flush())
    }
}
