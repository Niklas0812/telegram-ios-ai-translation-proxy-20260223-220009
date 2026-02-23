import Foundation

public enum AITranslationDirection: String {
    case incoming
    case outgoing
}

public struct AITranslationDisplayResult {
    public let text: String
    public let wasTranslated: Bool
    public let originalText: String

    public init(text: String, wasTranslated: Bool, originalText: String) {
        self.text = text
        self.wasTranslated = wasTranslated
        self.originalText = originalText
    }
}

/// Main coordination service used by Telegram-iOS hook patches.
/// This file is intentionally dependency-light so it can be copied into upstream and then wired to
/// TelegramUI / TelegramCore through small patch surfaces.
public final class AITranslationService {
    public static let shared = AITranslationService()

    private let config: AITranslationConfig
    private let proxyClient: AIProxyClient
    private let cache: TranslationCache
    private let contextProvider: ConversationContextProviding

    public init(
        config: AITranslationConfig = .shared,
        proxyClient: AIProxyClient = AIProxyClient(),
        cache: TranslationCache = .shared,
        contextProvider: ConversationContextProviding = ConversationContextProvider()
    ) {
        self.config = config
        self.proxyClient = proxyClient
        self.cache = cache
        self.contextProvider = contextProvider
    }

    public func isEnabled(chatID: String?, direction: AITranslationDirection) -> Bool {
        config.isEnabled(forChatID: chatID, directionIncoming: direction == .incoming)
    }

    public func translateOutgoing(text: String, chatID: String?) async -> String {
        guard !text.isEmpty else { return text }
        guard isEnabled(chatID: chatID, direction: .outgoing) else { return text }

        let settings = config.load()
        let context = buildContext(settings: settings, chatID: chatID)
        let request = AIProxyTranslateRequest(text: text, direction: AITranslationDirection.outgoing.rawValue, chatId: chatID, context: context)
        let response = await proxyClient.translate(baseURL: settings.proxyBaseURL, request: request)
        return response.translatedText
    }

    public func translateIncomingDisplayText(text: String, chatID: String?, messageKey: String) async -> AITranslationDisplayResult {
        guard !text.isEmpty else { return AITranslationDisplayResult(text: text, wasTranslated: false, originalText: text) }
        guard isEnabled(chatID: chatID, direction: .incoming) else { return AITranslationDisplayResult(text: text, wasTranslated: false, originalText: text) }

        let cacheKey = "incoming|\(messageKey)|\(text.hashValue)"
        if let cached = cache.value(forKey: cacheKey) {
            return AITranslationDisplayResult(text: cached, wasTranslated: cached != text, originalText: text)
        }

        let settings = config.load()
        let request = AIProxyTranslateRequest(text: text, direction: AITranslationDirection.incoming.rawValue, chatId: chatID, context: [])
        let response = await proxyClient.translate(baseURL: settings.proxyBaseURL, request: request)
        cache.setValue(response.translatedText, forKey: cacheKey)
        return AITranslationDisplayResult(text: response.translatedText, wasTranslated: response.translatedText != text, originalText: text)
    }

    public func testConnection() async -> Bool {
        let settings = config.load()
        return await proxyClient.checkHealth(baseURL: settings.proxyBaseURL)
    }

    private func buildContext(settings: AITranslationSettings, chatID: String?) -> [AIProxyContextMessage] {
        guard settings.contextMode == .conversationContext,
              let chatID,
              settings.contextMessageCount >= 2 else {
            return []
        }

        return contextProvider
            .recentContext(chatID: chatID, limit: min(100, max(2, settings.contextMessageCount)))
            .map { AIProxyContextMessage(role: $0.role, text: $0.text) }
    }
}
