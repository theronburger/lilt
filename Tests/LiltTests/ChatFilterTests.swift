import XCTest
@testable import Lilt

final class ChatFilterTests: XCTestCase {
    func testBaseURLAndExplicitFormat() throws {
        XCTAssertEqual(try AITextFilter.endpoint("https://openrouter.ai/api/v1/", format: .chat).absoluteString, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertEqual(try AITextFilter.endpoint("https://example.com/v1", format: .responses).absoluteString, "https://example.com/v1/responses")
        for url in ["https://example.com/v1/chat/completions", "https://example.com/v1/responses/"] {
            XCTAssertThrowsError(try AITextFilter.endpoint(url))
        }
    }
    func testChatStreamingRejectsTruncationAndProviderErrors() throws {
        var stream = ChatFilterStream()
        XCTAssertFalse(try stream.consume(Data(#"{"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}"#.utf8)))
        XCTAssertTrue(try stream.consume(Data(#"{"choices":[{"delta":{},"finish_reason":"stop"}]}"#.utf8)))
        XCTAssertEqual(stream.text, "Hello")
        XCTAssertThrowsError(try stream.consume(Data(#"{"choices":[{"delta":{},"finish_reason":"length"}]}"#.utf8)))
        XCTAssertThrowsError(try stream.consume(Data(#"{"error":{"message":"Failure"}}"#.utf8)))
        XCTAssertThrowsError(try stream.consume(Data(#"{"choices":[{"delta":{"refusal":"No"}}]}"#.utf8)))
    }
    func testNonStreamingChat() throws {
        XCTAssertEqual(try ChatFilterStream.completedText(Data(#"{"choices":[{"message":{"content":"Hello"},"finish_reason":"stop"}]}"#.utf8)), "Hello")
        XCTAssertThrowsError(try ChatFilterStream.completedText(Data(#"{"choices":[{"message":{"content":"Partial"},"finish_reason":"length"}]}"#.utf8)))
    }
}
