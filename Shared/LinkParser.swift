import Foundation

enum Platform: String, Codable, CaseIterable {
    case douyin, bilibili, xiaohongshu, youtube, wechat, weibo, kuaishou, other

    var displayName: String {
        switch self {
        case .douyin: "抖音"
        case .bilibili: "B站"
        case .xiaohongshu: "小红书"
        case .youtube: "YouTube"
        case .wechat: "微信"
        case .weibo: "微博"
        case .kuaishou: "快手"
        case .other: "网页"
        }
    }

    fileprivate var domains: [String] {
        switch self {
        case .douyin: ["douyin.com", "iesdouyin.com"]
        case .bilibili: ["bilibili.com", "b23.tv"]
        case .xiaohongshu: ["xiaohongshu.com", "xhslink.com"]
        case .youtube: ["youtube.com", "youtu.be"]
        case .wechat: ["weixin.qq.com"]
        case .weibo: ["weibo.com", "weibo.cn"]
        case .kuaishou: ["kuaishou.com"]
        case .other: []
        }
    }
}

struct ParsedShare: Equatable {
    let url: URL
    let platform: Platform
    /// A title guessed from the text around the link (share texts from Douyin,
    /// Bilibili and Xiaohongshu usually contain the video title).
    let titleHint: String?
}

/// Turns whatever a social app puts on the clipboard or into the share sheet
/// ("7.69 复制打开抖音，看看【某某的作品】标题… https://v.douyin.com/xxx/ …")
/// into a link, a platform and a title hint.
enum LinkParser {
    static func parse(_ text: String) -> ParsedShare? {
        guard let found = firstLink(in: text) else { return nil }
        let before = clean(String(text[..<found.range.lowerBound]))
        let after = clean(String(text[found.range.upperBound...]))
        let hint = [before, after].first { $0.count >= 2 }
        return ParsedShare(url: found.url, platform: platform(for: found.url), titleHint: hint)
    }

    static func firstLink(in text: String) -> (url: URL, range: Range<String.Index>)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  let range = Range(match.range, in: text) else { continue }
            return (url, range)
        }
        return nil
    }

    static func platform(for url: URL) -> Platform {
        guard let host = url.host()?.lowercased() else { return .other }
        let match = Platform.allCases.first { platform in
            platform.domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }
        return match ?? .other
    }

    /// Boilerplate that share texts wrap around the real title. Order matters.
    private static let noisePatterns = [
        "复制打开抖音[，,]?\\s*看看",
        "复制此链接[，,]?\\s*打开抖音搜索[，,]?\\s*直接观看视频[！!]?",
        "复制本条信息[，,]?\\s*打开【小红书】\\s*App\\s*查看精彩内容[！!]?",
        "【[^】]*的作品】",
        "[-_]\\s*哔哩哔哩[^】]*",
        "^\\s*\\d+(\\.\\d+)?\\s+",
        "\\s\\d{1,2}/\\d{1,2}(\\s.*)?$",
        "\\S*@\\S*\\.\\S*",
        "\\S*:/\\S*",
        "#\\s?\\S+",
    ]

    private static let trimSet = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ",，。.!！:：;；-—|/、~"))

    static func clean(_ raw: String) -> String {
        var text = raw
        for pattern in noisePatterns {
            text = text.removingMatches(of: pattern)
        }
        text = text
            .replacingOccurrences(of: "【", with: " ")
            .replacingOccurrences(of: "】", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: trimSet)
        if text.count > 80 {
            text = String(text.prefix(80)) + "…"
        }
        return text
    }
}
