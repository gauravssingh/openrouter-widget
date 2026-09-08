import Foundation

/// Formats OpenRouter model slugs into compact, human-readable names.
/// `anthropic/claude-sonnet-4.5` → `Claude Sonnet 4.5`,
/// `openai/gpt-4o` → `GPT 4o`, `z-ai/glm-4.6` → `GLM 4.6`.
public enum ModelNameFormatter {
    private static let knownAcronyms: Set<String> = [
        "gpt", "glm", "ai", "llama", "sora", "qwen", "yolo", "ocr", "sql", "flux"
    ]

    /// Full short names that need special handling because generic
    /// tokenization would mangle them.
    private static let specialCases: [String: String] = [
        "dall-e-3": "DALL-E 3",
        "dall-e-2": "DALL-E 2"
    ]

    public static func displayName(for slug: String) -> String {
        let shortName = slug.split(separator: "/").last.map(String.init) ?? slug
        if let special = specialCases[shortName.lowercased()] {
            return special
        }
        let tokens = shortName.split(separator: "-").map(String.init)
        guard !tokens.isEmpty else { return shortName }

        let formatted = tokens.map { token -> String in
            let lower = token.lowercased()
            if knownAcronyms.contains(lower) {
                return uppercasedAcronym(lower)
            }
            if let first = token.first, first.isNumber {
                return token // version fragments: "4.1", "4o", "3.7", "2.5"
            }
            if token.count <= 2 {
                return lower.uppercased() // "o3", "vx"
            }
            return token.prefix(1).uppercased() + token.dropFirst()
        }
        return formatted.joined(separator: " ")
    }

    /// Keeps a few well-known spellings intact (`llama` → `Llama`).
    private static func uppercasedAcronym(_ lower: String) -> String {
        switch lower {
        case "llama": return "Llama"
        case "qwen": return "Qwen"
        case "sora": return "Sora"
        case "flux": return "FLUX"
        default: return lower.uppercased()
        }
    }
}
