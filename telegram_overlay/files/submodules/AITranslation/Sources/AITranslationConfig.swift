import Foundation

public enum AITranslationContextMode: String, Codable {
    case singleMessage
    case conversationContext
}

public struct AITranslationSettings: Codable, Equatable {
    public var globalEnabled: Bool = false
    public var translateIncomingEnabled: Bool = true
    public var translateOutgoingEnabled: Bool = true
    public var proxyBaseURL: String = ""
    public var showRawAPIResponses: Bool = false
    public var contextMode: AITranslationContextMode = .singleMessage
    public var contextMessageCount: Int = 20
    public var perChatEnabled: [String: Bool] = [:]

    public init() {}
}

public final class AITranslationConfig {
    public static let shared = AITranslationConfig()

    private let defaults: UserDefaults
    private let key = "ai_translation.settings.v1"
    private let queue = DispatchQueue(label: "AITranslationConfig")

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AITranslationSettings {
        queue.sync {
            guard let data = defaults.data(forKey: key) else { return AITranslationSettings() }
            do {
                return try JSONDecoder().decode(AITranslationSettings.self, from: data)
            } catch {
                return AITranslationSettings()
            }
        }
    }

    public func save(_ settings: AITranslationSettings) {
        queue.sync {
            guard let data = try? JSONEncoder().encode(settings) else { return }
            defaults.set(data, forKey: key)
        }
    }

    public func update(_ mutate: (inout AITranslationSettings) -> Void) {
        var settings = load()
        mutate(&settings)
        save(settings)
    }

    public func isEnabled(forChatID chatID: String?, directionIncoming: Bool) -> Bool {
        let settings = load()
        guard settings.globalEnabled else { return false }
        if directionIncoming && !settings.translateIncomingEnabled { return false }
        if !directionIncoming && !settings.translateOutgoingEnabled { return false }
        guard let chatID else { return true }
        return settings.perChatEnabled[chatID] ?? true
    }
    
    public func perChatOverride(forChatID chatID: String?) -> Bool? {
        guard let chatID else { return nil }
        let settings = load()
        return settings.perChatEnabled[chatID]
    }
    
    @discardableResult
    public func setPerChatEnabled(_ enabled: Bool, forChatID chatID: String?) -> Bool {
        guard let chatID else { return enabled }
        update { settings in
            if enabled {
                settings.perChatEnabled.removeValue(forKey: chatID)
            } else {
                settings.perChatEnabled[chatID] = false
            }
        }
        return enabled
    }
    
    @discardableResult
    public func togglePerChatEnabled(forChatID chatID: String?) -> Bool {
        guard let chatID else { return true }
        let current = load().perChatEnabled[chatID] ?? true
        let updated = !current
        _ = setPerChatEnabled(updated, forChatID: chatID)
        return updated
    }
}
