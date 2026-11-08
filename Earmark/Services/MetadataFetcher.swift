import Foundation

struct LinkMetadata: Equatable {
    var title: String?
    var thumbnailURL: URL?
    var durationSeconds: Int?
}

/// Best-effort lookup of title, cover and duration. Every step may fail
/// (platforms change their pages often); callers just keep what they had.
enum MetadataFetcher {
    private static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    /// Page titles that only name the site, not the content.
    private static let genericTitles: Set<String> = ["抖音", "哔哩哔哩", "小红书", "youtube", "微博", "快手", "微信"]

    static func fetch(url: URL, platform: Platform) async -> LinkMetadata {
        switch platform {
        case .youtube:
            if let metadata = await youtube(url) { return metadata }
        case .bilibili:
            if let metadata = await bilibili(url) { return metadata }
        default:
            break
        }
        return await html(url) ?? LinkMetadata()
    }

    private struct Fetched {
        let data: Data
        let finalURL: URL
    }

    private static func get(_ url: URL) async -> Fetched? {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let result = try? await URLSession.shared.data(for: request),
              let http = result.1 as? HTTPURLResponse,
              (200..<400).contains(http.statusCode) else { return nil }
        return Fetched(data: result.0, finalURL: http.url ?? url)
    }

    private static func json(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // MARK: YouTube

    private static func youtube(_ url: URL) async -> LinkMetadata? {
        guard var components = URLComponents(string: "https://www.youtube.com/oembed") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let endpoint = components.url,
              let fetched = await get(endpoint),
              let body = json(fetched.data) else { return nil }
        return LinkMetadata(
            title: body["title"] as? String,
            thumbnailURL: (body["thumbnail_url"] as? String).flatMap { URL(string: $0) },
            durationSeconds: nil
        )
    }

    // MARK: Bilibili

    static func bvid(in text: String) -> String? {
        text.captureGroups(matching: "(BV[0-9A-Za-z]{10})", options: [])?[1]
    }

    private static func bilibili(_ url: URL) async -> LinkMetadata? {
        var target = url
        if bvid(in: target.absoluteString) == nil, let resolved = await get(url) {
            target = resolved.finalURL // b23.tv short links redirect to the full video URL
        }
        guard let id = bvid(in: target.absoluteString),
              let endpoint = URL(string: "https://api.bilibili.com/x/web-interface/view?bvid=\(id)"),
              let fetched = await get(endpoint),
              let body = json(fetched.data),
              let data = body["data"] as? [String: Any] else { return nil }
        let cover = (data["pic"] as? String)?.replacingOccurrences(of: "http://", with: "https://")
        return LinkMetadata(
            title: data["title"] as? String,
            thumbnailURL: cover.flatMap { URL(string: $0) },
            durationSeconds: data["duration"] as? Int
        )
    }

    // MARK: Generic web page

    private static func html(_ url: URL) async -> LinkMetadata? {
        guard let fetched = await get(url) else { return nil }
        let page = String(decoding: fetched.data.prefix(500_000), as: UTF8.self)

        let rawTitle = metaContent("og:title", in: page) ?? page.captureGroups(matching: "<title[^>]*>([^<]+)</title>")?[1]
        let title = rawTitle
            .map { decodeEntities($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty || genericTitles.contains($0.lowercased()) ? nil : $0 }
        let image = metaContent("og:image", in: page).map(decodeEntities).flatMap { URL(string: $0) }
        let duration = isoDuration(in: page) ?? metaContent("video:duration", in: page).flatMap { Int($0) }

        return LinkMetadata(title: title, thumbnailURL: image, durationSeconds: duration)
    }

    private static func metaContent(_ property: String, in page: String) -> String? {
        let name = NSRegularExpression.escapedPattern(for: property)
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(name)[\"'][^>]*content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]*(?:property|name)=[\"']\(name)[\"']",
        ]
        for pattern in patterns {
            if let groups = page.captureGroups(matching: pattern), !groups[1].isEmpty {
                return groups[1]
            }
        }
        return nil
    }

    /// Reads schema.org durations such as "PT12M30S".
    static func isoDuration(in page: String) -> Int? {
        guard let groups = page.captureGroups(
            matching: "\"duration\"\\s*:\\s*\"PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?\""
        ) else { return nil }
        let total = (Int(groups[1]) ?? 0) * 3600 + (Int(groups[2]) ?? 0) * 60 + (Int(groups[3]) ?? 0)
        return total > 0 ? total : nil
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
