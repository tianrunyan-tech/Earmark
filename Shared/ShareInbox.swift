import Foundation

struct PendingShare: Codable, Equatable {
    let text: String
    let sharedAt: Date
}

/// Hand-off between the share extension and the app. The extension appends
/// raw share text into the App Group; the app drains it when it comes to the
/// foreground and turns each entry into a queue item.
enum ShareInbox {
    /// Must match the App Group in both .entitlements files.
    static let appGroupID = "group.com.tianrunyan.earmark"
    private static let key = "pendingShares"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    @discardableResult
    static func append(_ text: String, at date: Date = .now) -> Bool {
        guard let defaults else { return false }
        var items = load(from: defaults)
        items.append(PendingShare(text: text, sharedAt: date))
        guard let data = try? JSONEncoder().encode(items) else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    static func drain() -> [PendingShare] {
        guard let defaults else { return [] }
        let items = load(from: defaults)
        defaults.removeObject(forKey: key)
        return items
    }

    private static func load(from defaults: UserDefaults) -> [PendingShare] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingShare].self, from: data)) ?? []
    }
}
