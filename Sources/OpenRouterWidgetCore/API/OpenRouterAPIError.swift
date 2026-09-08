import Foundation

/// Typed errors surfaced by the OpenRouter API client.
public enum OpenRouterAPIError: Error, Equatable, Sendable {
    case missingAPIKey
    case unauthorized(message: String?)
    case forbidden(message: String?)
    case rateLimited(message: String?)
    case badRequest(message: String?)
    case serverError(status: Int, message: String?)
    case networkUnavailable(String)
    case timeout
    case invalidResponse
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No OpenRouter API key is configured."
        case .unauthorized(let message):
            return "OpenRouter rejected this API key.\(messageSuffix(message))"
        case .forbidden(let message):
            return "Access denied.\(messageSuffix(message))"
        case .rateLimited(let message):
            return "OpenRouter rate limited the request. Try again shortly.\(messageSuffix(message))"
        case .badRequest(let message):
            return "OpenRouter rejected the request.\(messageSuffix(message))"
        case .serverError(let status, let message):
            return "OpenRouter server error (\(status)).\(messageSuffix(message))"
        case .networkUnavailable(let detail):
            return "Network unavailable: \(detail)"
        case .timeout:
            return "The request timed out."
        case .invalidResponse:
            return "OpenRouter returned an invalid response."
        case .decodingFailed:
            return "Could not read OpenRouter's response."
        }
    }

    /// True when the failure means the key lacks management permissions.
    public var requiresManagementKey: Bool {
        if case .forbidden = self { return true }
        return false
    }

    private func messageSuffix(_ message: String?) -> String {
        guard let message, !message.isEmpty else { return "" }
        return " OpenRouter returned: \(message)"
    }

    static func from(_ error: URLError) -> OpenRouterAPIError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
            return .networkUnavailable(error.localizedDescription)
        default:
            return .networkUnavailable(error.localizedDescription)
        }
    }
}
