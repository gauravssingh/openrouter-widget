import Foundation

// MARK: - Responses

public struct KeyInfoResponse: Codable, Equatable, Sendable {
    public let data: KeyInfo
}

public struct CreditsResponse: Codable, Equatable, Sendable {
    public let data: Credits
}

public struct ActivityResponse: Codable, Equatable, Sendable {
    public let data: [ActivityItem]
}

/// OpenRouter error body: `{ "error": { "code": number, "message": string } }`.
struct APIErrorBody: Codable, Sendable {
    struct ErrorData: Codable, Sendable {
        let code: Int?
        let message: String?
    }

    let error: ErrorData?
}

// MARK: - /api/v1/key

/// Information about the authenticated API key.
public struct KeyInfo: Codable, Equatable, Sendable {
    public let label: String
    public let usage: Double
    public let usageDaily: Double
    public let usageWeekly: Double
    public let usageMonthly: Double
    public let byokUsage: Double
    public let byokUsageDaily: Double
    public let byokUsageWeekly: Double
    public let byokUsageMonthly: Double
    public let limit: Double?
    public let limitRemaining: Double?
    public let limitReset: String?
    public let includeByokInLimit: Bool
    public let isFreeTier: Bool
    public let isManagementKey: Bool
    public let isProvisioningKey: Bool
    public let expiresAt: String?
    public let creatorUserId: String?

    /// Spend so far today (current UTC day) through this key, in USD.
    public var totalDailyUsage: Double { usageDaily + byokUsageDaily }
    /// Current UTC week (Monday–Sunday) spend through this key, in USD.
    public var totalWeeklyUsage: Double { usageWeekly + byokUsageWeekly }
    /// Current UTC month spend through this key, in USD.
    public var totalMonthlyUsage: Double { usageMonthly + byokUsageMonthly }

    public init(
        label: String,
        usage: Double,
        usageDaily: Double,
        usageWeekly: Double,
        usageMonthly: Double,
        byokUsage: Double,
        byokUsageDaily: Double,
        byokUsageWeekly: Double,
        byokUsageMonthly: Double,
        limit: Double?,
        limitRemaining: Double?,
        limitReset: String?,
        includeByokInLimit: Bool,
        isFreeTier: Bool,
        isManagementKey: Bool,
        isProvisioningKey: Bool,
        expiresAt: String?,
        creatorUserId: String?
    ) {
        self.label = label
        self.usage = usage
        self.usageDaily = usageDaily
        self.usageWeekly = usageWeekly
        self.usageMonthly = usageMonthly
        self.byokUsage = byokUsage
        self.byokUsageDaily = byokUsageDaily
        self.byokUsageWeekly = byokUsageWeekly
        self.byokUsageMonthly = byokUsageMonthly
        self.limit = limit
        self.limitRemaining = limitRemaining
        self.limitReset = limitReset
        self.includeByokInLimit = includeByokInLimit
        self.isFreeTier = isFreeTier
        self.isManagementKey = isManagementKey
        self.isProvisioningKey = isProvisioningKey
        self.expiresAt = expiresAt
        self.creatorUserId = creatorUserId
    }
}

// MARK: - /api/v1/credits

/// Account-level credit totals (management key required).
public struct Credits: Codable, Equatable, Sendable {
    public let totalCredits: Double
    public let totalUsage: Double

    /// Remaining account credit in USD: purchased minus used.
    public var remaining: Double { totalCredits - totalUsage }

    public init(totalCredits: Double, totalUsage: Double) {
        self.totalCredits = totalCredits
        self.totalUsage = totalUsage
    }
}

// MARK: - /api/v1/activity

/// One activity row: spend for one (UTC day, model, endpoint) combination.
public struct ActivityItem: Codable, Equatable, Sendable, Identifiable {
    /// UTC day label, `YYYY-MM-DD`.
    public let date: String
    public let model: String
    public let modelPermaslug: String?
    public let endpointId: String
    public let providerName: String
    /// Cost in USD (OpenRouter credits spent).
    public let usage: Double
    /// BYOK inference cost in USD (external credits).
    public let byokUsageInference: Double
    public let requests: Int
    public let promptTokens: Int
    public let completionTokens: Int
    public let reasoningTokens: Int

    public var id: String { "\(date)-\(endpointId)-\(model)" }

    /// Total spend attributed to this row.
    public var totalCost: Double { usage + byokUsageInference }

    public init(
        date: String,
        model: String,
        modelPermaslug: String?,
        endpointId: String,
        providerName: String,
        usage: Double,
        byokUsageInference: Double,
        requests: Int,
        promptTokens: Int,
        completionTokens: Int,
        reasoningTokens: Int
    ) {
        self.date = date
        self.model = model
        self.modelPermaslug = modelPermaslug
        self.endpointId = endpointId
        self.providerName = providerName
        self.usage = usage
        self.byokUsageInference = byokUsageInference
        self.requests = requests
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
    }
}
