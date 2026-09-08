import Foundation
import os

/// Network interface to the OpenRouter API. Implementations must be free of
/// SwiftUI dependencies and safe to call from any executor.
public protocol OpenRouterAPI: Sendable {
    /// Information about the authenticated key. Works with any valid key.
    func getKeyInfo(apiKey: String) async throws -> KeyInfo
    /// Account credit totals. Requires a management key.
    func getCredits(apiKey: String) async throws -> Credits
    /// Activity for the last 30 completed UTC days. Requires a management key.
    func getActivity(apiKey: String) async throws -> [ActivityItem]
    /// Exact account-wide spend (USD) for an arbitrary time range.
    /// Requires a management key.
    func getSpendTotal(apiKey: String, from start: Date, to end: Date) async throws -> Double
}

/// `URLSession`-backed client. All requests are built centrally, authenticated
/// here, and decoded with a single snake_case-tolerant decoder.
public final class OpenRouterAPIClient: OpenRouterAPI, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    public func getKeyInfo(apiKey: String) async throws -> KeyInfo {
        AppLog.api.info("Fetching key info")
        let response: KeyInfoResponse = try await get(path: "key", apiKey: apiKey)
        AppLog.api.info("Key info request completed")
        return response.data
    }

    public func getCredits(apiKey: String) async throws -> Credits {
        AppLog.api.info("Fetching credits")
        let response: CreditsResponse = try await get(path: "credits", apiKey: apiKey)
        AppLog.api.info("Credits request completed")
        return response.data
    }

    public func getActivity(apiKey: String) async throws -> [ActivityItem] {
        AppLog.api.info("Fetching activity")
        let response: ActivityResponse = try await get(path: "activity", apiKey: apiKey)
        AppLog.api.info("Activity request completed: \(response.data.count) rows")
        return response.data
    }

    public func getSpendTotal(apiKey: String, from start: Date, to end: Date) async throws -> Double {
        AppLog.api.info("Fetching spend total")
        let body = AnalyticsQueryRequest(
            metrics: ["total_usage"],
            timeRange: .init(
                start: Self.isoTimestamp(start),
                end: Self.isoTimestamp(end)
            )
        )
        let response: AnalyticsQueryResponse = try await post(path: "analytics/query", apiKey: apiKey, body: body)
        let total = response.data.data.reduce(0) { $0 + ($1.totalUsage?.value ?? 0) }
        AppLog.api.info("Spend total request completed")
        return total
    }

    private static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    // MARK: - Internals

    private func get<Response: Decodable>(path: String, apiKey: String) async throws -> Response {
        let requestData = try await performRequest(path: path, apiKey: apiKey, payload: nil, method: "GET")
        do {
            return try decoder.decode(Response.self, from: requestData)
        } catch {
            AppLog.api.error("Decoding failed: \(String(describing: error))")
            throw OpenRouterAPIError.decodingFailed(String(describing: error))
        }
    }

    private func post<Response: Decodable>(
        path: String,
        apiKey: String,
        body: some Encodable
    ) async throws -> Response {
        let payload: Data
        do {
            payload = try JSONEncoder().encode(body)
        } catch {
            throw OpenRouterAPIError.invalidResponse
        }
        let requestData = try await performRequest(path: path, apiKey: apiKey, payload: payload, method: "POST")
        do {
            return try decoder.decode(Response.self, from: requestData)
        } catch {
            AppLog.api.error("Decoding failed: \(String(describing: error))")
            throw OpenRouterAPIError.decodingFailed(String(describing: error))
        }
    }

    /// Shared request/response plumbing for GET and POST.
    private func performRequest(
        path: String,
        apiKey: String,
        payload: Data?,
        method: String
    ) async throws -> Data {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenRouterAPIError.missingAPIKey }

        let components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        guard let url = components?.url else { throw OpenRouterAPIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let payload {
            request.httpBody = payload
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch let error as URLError {
            throw OpenRouterAPIError.from(error)
        } catch {
            throw OpenRouterAPIError.networkUnavailable(error.localizedDescription)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw OpenRouterAPIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw errorBody(for: http, data: data)
        }

        return data
    }

    private func errorBody(for http: HTTPURLResponse, data: Data) -> OpenRouterAPIError {
        let message: String? = (try? decoder.decode(APIErrorBody.self, from: data))?.error?.message
        switch http.statusCode {
        case 400:
            return .badRequest(message: message)
        case 401:
            return .unauthorized(message: message)
        case 403:
            return .forbidden(message: message)
        case 429:
            return .rateLimited(message: message)
        case 500..<600:
            return .serverError(status: http.statusCode, message: message)
        default:
            return .invalidResponse
        }
    }
}
