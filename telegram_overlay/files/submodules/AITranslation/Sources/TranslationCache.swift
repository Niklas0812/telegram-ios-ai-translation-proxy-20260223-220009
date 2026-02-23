import Foundation

public final class TranslationCache {
    public static let shared = TranslationCache()

    private final class Box: NSObject {
        let value: String
        init(_ value: String) { self.value = value }
    }

    private let cache = NSCache<NSString, Box>()

    public init() {
        cache.countLimit = 500
    }

    public func value(forKey key: String) -> String? {
        cache.object(forKey: key as NSString)?.value
    }

    public func setValue(_ value: String, forKey key: String) {
        cache.setObject(Box(value), forKey: key as NSString)
    }

    public func removeAll() {
        cache.removeAllObjects()
    }
}
