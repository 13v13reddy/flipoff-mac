import Foundation

struct FlipOffAgentState: Codable, Equatable, Sendable {
    var message: String?
    var author: String?
    var paused: Bool
    var rotationSeconds: Double
    var accentHex: String
    var quoteIndex: Int
    var updatedAt: String?
    var source: String?

    enum CodingKeys: String, CodingKey {
        case message
        case author
        case paused
        case rotationSeconds = "rotation_seconds"
        case accentHex = "accent_hex"
        case quoteIndex = "quote_index"
        case updatedAt = "updated_at"
        case source
    }

    var overrideQuote: FlipOffQuote? {
        guard let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var lines = message.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        lines = Array(lines.prefix(5))
        if let author, !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- \(author.trimmingCharacters(in: CharacterSet(charactersIn: "- ").union(.whitespacesAndNewlines)))")
        }
        lines = Array(lines.prefix(5))
        lines.append(contentsOf: Array(repeating: "", count: max(0, 5 - lines.count)))
        return FlipOffQuote(id: -1, lines: lines)
    }
}

enum FlipOffAgentStateStore {
    static let appGroupIdentifier = "group.com.flipoff.shared"

    static func stateURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["FLIPOFF_STATE_FILE"], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
        }

        let groupRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers")
            .appendingPathComponent(appGroupIdentifier)
        if FileManager.default.fileExists(atPath: groupRoot.path) {
            return groupRoot.appendingPathComponent("agent-state.json")
        }

        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier),
           FileManager.default.fileExists(atPath: groupURL.path) {
            return groupURL.appendingPathComponent("agent-state.json")
        }

        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport.appendingPathComponent("FlipOff/agent-state.json")
    }

    static func load() -> FlipOffAgentState? {
        guard let data = try? Data(contentsOf: stateURL()) else { return nil }
        return try? JSONDecoder().decode(FlipOffAgentState.self, from: data)
    }

    static func quote(for date: Date) -> FlipOffQuote {
        load()?.overrideQuote ?? FlipOffQuotes.quote(for: date)
    }
}
