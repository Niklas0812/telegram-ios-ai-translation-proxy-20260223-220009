import Foundation

public struct AIProxyContextMessage: Codable, Equatable {
    public let role: String
    public let text: String

    public init(role: String, text: String) {
        self.role = role
        self.text = text
    }
}

public struct AIProxyTranslateRequest: Codable, Equatable {
    public let text: String
    public let direction: String
    public let chatId: String?
    public let context: [AIProxyContextMessage]

    enum CodingKeys: String, CodingKey {
        case text
        case direction
        case chatId = "chat_id"
        case context
    }

    public init(text: String, direction: String, chatId: String?, context: [AIProxyContextMessage]) {
        self.text = text
        self.direction = direction
        self.chatId = chatId
        self.context = context
    }
}

public struct AIProxyTranslateResponse: Codable, Equatable {
    public let translatedText: String
    public let originalText: String
    public let direction: String
    public let translationFailed: Bool

    enum CodingKeys: String, CodingKey {
        case translatedText = "translated_text"
        case originalText = "original_text"
        case direction
        case translationFailed = "translation_failed"
    }
}

public enum AIProxyClientError: Error {
    case invalidURL
    case network(Error)
    case invalidResponse
    case decode(Error)
}

public final class AIProxyClient {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 15.0) {
        self.session = session
        self.timeout = timeout
    }

    public func translate(baseURL: String, request: AIProxyTranslateRequest) async -> AIProxyTranslateResponse {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: normalizedBaseURL + "/translate") else {
            return AIProxyTranslateResponse(translatedText: request.text, originalText: request.text, direction: request.direction, translationFailed: true)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return AIProxyTranslateResponse(translatedText: request.text, originalText: request.text, direction: request.direction, translationFailed: true)
            }
            do {
                return try JSONDecoder().decode(AIProxyTranslateResponse.self, from: data)
            } catch {
                return AIProxyTranslateResponse(translatedText: request.text, originalText: request.text, direction: request.direction, translationFailed: true)
            }
        } catch {
            return AIProxyTranslateResponse(translatedText: request.text, originalText: request.text, direction: request.direction, translationFailed: true)
        }
    }

    public func checkHealth(baseURL: String) async -> Bool {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: normalizedBaseURL + "/health") else {
            return false
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 5
        do {
            let (_, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
