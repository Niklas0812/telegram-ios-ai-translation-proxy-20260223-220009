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
    private let stateQueue = DispatchQueue(label: "AITranslationService.state")
    private var inflightIncomingKeys: Set<String> = []

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

        let cacheKey = incomingCacheKey(text: text, messageKey: messageKey)
        if let cached = cache.value(forKey: cacheKey) {
            return AITranslationDisplayResult(text: cached, wasTranslated: cached != text, originalText: text)
        }

        let settings = config.load()
        let request = AIProxyTranslateRequest(text: text, direction: AITranslationDirection.incoming.rawValue, chatId: chatID, context: [])
        let response = await proxyClient.translate(baseURL: settings.proxyBaseURL, request: request)
        cache.setValue(response.translatedText, forKey: cacheKey)
        return AITranslationDisplayResult(text: response.translatedText, wasTranslated: response.translatedText != text, originalText: text)
    }
    
    public func cachedIncomingDisplayTranslation(text: String, messageKey: String, chatID: String?) -> String? {
        guard !text.isEmpty else { return text }
        guard isEnabled(chatID: chatID, direction: .incoming) else { return nil }
        return cache.value(forKey: incomingCacheKey(text: text, messageKey: messageKey))
    }
    
    public func requestIncomingDisplayTranslationIfNeeded(
        text: String,
        chatID: String?,
        messageKey: String,
        onUpdate: @escaping () -> Void
    ) {
        guard !text.isEmpty else { return }
        guard isEnabled(chatID: chatID, direction: .incoming) else { return }
        
        let cacheKey = incomingCacheKey(text: text, messageKey: messageKey)
        if cache.value(forKey: cacheKey) != nil {
            return
        }
        
        let shouldStart = stateQueue.sync { () -> Bool in
            if inflightIncomingKeys.contains(cacheKey) {
                return false
            }
            inflightIncomingKeys.insert(cacheKey)
            return true
        }
        
        guard shouldStart else { return }
        
        Task { [weak self] in
            guard let self else { return }
            _ = await self.translateIncomingDisplayText(text: text, chatID: chatID, messageKey: messageKey)
            _ = self.stateQueue.sync {
                self.inflightIncomingKeys.remove(cacheKey)
            }
            DispatchQueue.main.async {
                onUpdate()
            }
        }
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
    
    private func incomingCacheKey(text: String, messageKey: String) -> String {
        "incoming|\(messageKey)|\(text.hashValue)"
    }
}
