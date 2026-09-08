import Foundation
import OpenRouterWidgetCore
import XCTest

/// URLProtocol mock so the real client can be exercised without network.
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        guard let handler = Self.handler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.notConnectedToInternet)
            )
            return
        }
        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class APIClientTests: XCTestCase {
    private var client: OpenRouterAPIClient!
    private let apiKey = "sk-or-v1-test-key-000000"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        client = OpenRouterAPIClient(
            baseURL: URL(string: "https://openrouter.example/api/v1")!,
            session: URLSession(configuration: config)
        )
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        MockURLProtocol.lastRequest = nil
        super.tearDown()
    }

    private func setErrorResponse(_ status: Int, message: String) {
        let body = "{\"error\":{\"code\":\(status),\"message\":\(JSONString(message))}}"
        MockURLProtocol.handler = { _ in (status, Data(body.utf8)) }
    }

    private func JSONString(_ s: String) -> String {
        "\"\(s)\""
    }

    // MARK: - Requests

    func testRequestIncludesBearerAuthorizationAndPath() async {
        MockURLProtocol.handler = { _ in
            (200, Data("{\"data\":{\"total_credits\":10,\"total_usage\":1}}".utf8))
        }
        _ = try? await client.getCredits(apiKey: apiKey)

        let request = MockURLProtocol.lastRequest
        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.url?.absoluteString, "https://openrouter.example/api/v1/credits")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer \(apiKey)")
    }

    func testMissingAPIKeyThrowsBeforeNetworking() async {
        await XCTAssertThrowsErrorAsync(try await client.getKeyInfo(apiKey: "  ")) { error in
            XCTAssertEqual(error as? OpenRouterAPIError, .missingAPIKey)
        }
    }

    // MARK: - Status code mapping

    func test401MapsToUnauthorized() async {
        setErrorResponse(401, message: "Missing Authentication header")
        await XCTAssertThrowsErrorAsync(try await client.getCredits(apiKey: apiKey)) { error in
            XCTAssertEqual(
                error as? OpenRouterAPIError,
                .unauthorized(message: "Missing Authentication header")
            )
            XCTAssertEqual(
                (error as? OpenRouterAPIError)?.requiresManagementKey, false
            )
        }
    }

    func test403MapsToForbidden() async {
        setErrorResponse(403, message: "Only management keys can perform this operation")
        await XCTAssertThrowsErrorAsync(try await client.getActivity(apiKey: apiKey)) { error in
            XCTAssertEqual(
                error as? OpenRouterAPIError,
                .forbidden(message: "Only management keys can perform this operation")
            )
            XCTAssertTrue((error as? OpenRouterAPIError)?.requiresManagementKey ?? false)
        }
    }

    func test429MapsToRateLimited() async {
        setErrorResponse(429, message: "Rate limit exceeded")
        await XCTAssertThrowsErrorAsync(try await client.getKeyInfo(apiKey: apiKey)) { error in
            XCTAssertEqual(
                error as? OpenRouterAPIError,
                .rateLimited(message: "Rate limit exceeded")
            )
        }
    }

    func test500MapsToServerError() async {
        setErrorResponse(500, message: "Internal Server Error")
        await XCTAssertThrowsErrorAsync(try await client.getKeyInfo(apiKey: apiKey)) { error in
            XCTAssertEqual(
                error as? OpenRouterAPIError,
                .serverError(status: 500, message: "Internal Server Error")
            )
        }
    }

    func testMalformedBodyMapsToDecodingFailure() async {
        MockURLProtocol.handler = { _ in (200, Data("not json".utf8)) }
        await XCTAssertThrowsErrorAsync(try await client.getCredits(apiKey: apiKey)) { error in
            guard case .decodingFailed = error as? OpenRouterAPIError else {
                return XCTFail("Expected decodingFailed, got \(error)")
            }
        }
    }

    func testNetworkUnavailableMapsToNetworkError() async {
        MockURLProtocol.handler = nil // startLoading fails with URLError
        await XCTAssertThrowsErrorAsync(try await client.getKeyInfo(apiKey: apiKey)) { error in
            guard case .networkUnavailable = error as? OpenRouterAPIError else {
                return XCTFail("Expected networkUnavailable, got \(error)")
            }
        }
    }

    func testTimeoutMapsToTimeout() async {
        MockURLProtocol.handler = { _ in
            throw URLError(.timedOut)
        }
        await XCTAssertThrowsErrorAsync(try await client.getKeyInfo(apiKey: apiKey)) { error in
            XCTAssertEqual(error as? OpenRouterAPIError, .timeout)
        }
    }

    // MARK: - Helpers

    private func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ check: (Error) -> Void
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error, got success", file: file, line: line)
        } catch {
            check(error)
        }
    }
}
