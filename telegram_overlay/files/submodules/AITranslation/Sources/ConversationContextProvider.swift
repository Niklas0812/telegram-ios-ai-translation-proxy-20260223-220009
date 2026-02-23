import Foundation

public struct ConversationContextItem: Equatable {
    public let role: String
    public let text: String

    public init(role: String, text: String) {
        self.role = role
        self.text = text
    }
}

public protocol ConversationContextProviding {
    func recentContext(chatID: String, limit: Int) -> [ConversationContextItem]
}

/// Placeholder provider. Telegram-iOS integration patches should implement this using Postbox/TelegramCore.
public final class ConversationContextProvider: ConversationContextProviding {
    public init() {}

    public func recentContext(chatID: String, limit: Int) -> [ConversationContextItem] {
        _ = (chatID, limit)
        return []
    }
}
