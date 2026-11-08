import Foundation

enum ListeningScene: String, CaseIterable, Identifiable {
    case cooking
    case commute
    case exercise
    case chores
    case focusTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cooking: "做饭"
        case .commute: "通勤"
        case .exercise: "运动"
        case .chores: "家务/其他"
        case .focusTime: "专心听"
        }
    }

    var symbol: String {
        switch self {
        case .cooking: "frying.pan"
        case .commute: "tram"
        case .exercise: "figure.run"
        case .chores: "house"
        case .focusTime: "book"
        }
    }

    /// Only a dedicated listening slot is suitable for "需要专注" content.
    var allowsFocusContent: Bool { self == .focusTime }

    fileprivate var keywords: [String] {
        switch self {
        case .cooking: ["做饭", "煮饭", "烧饭", "炒菜", "厨房", "做菜"]
        case .commute: ["通勤", "地铁", "公交", "开车", "上班", "下班", "路上", "坐车"]
        case .exercise: ["跑步", "健身", "运动", "散步", "骑车", "遛狗", "走路"]
        case .chores: ["家务", "洗碗", "打扫", "收拾", "洗衣", "叠衣服", "洗澡"]
        case .focusTime: ["专心", "认真", "学习", "安静", "坐下来", "专注"]
        }
    }
}

struct ListeningIntent: Equatable {
    var minMinutes: Int
    var maxMinutes: Int
    var scene: ListeningScene
}

/// Understands requests like "我要做饭，大概20-30分钟" or "通勤半小时" without
/// a network call. An LLM can take over the fuzzier cases later.
enum IntentParser {
    static func parse(_ raw: String, defaultScene: ListeningScene = .chores) -> ListeningIntent? {
        let text = normalizeNumbers(raw.lowercased())
        let scene = ListeningScene.allCases.first { scene in
            scene.keywords.contains { text.contains($0) }
        }
        let range = minutesRange(in: text)
        guard scene != nil || range != nil else { return nil }
        let minutes = range ?? (20, 30)
        return ListeningIntent(minMinutes: minutes.0, maxMinutes: minutes.1, scene: scene ?? defaultScene)
    }

    /// A single number like "30 分钟" is read as "up to 30, ideally at least 70% of it".
    static func range(upTo minutes: Int) -> (Int, Int) {
        (max(1, Int((Double(minutes) * 0.7).rounded(.down))), minutes)
    }

    static func minutesRange(in text: String) -> (Int, Int)? {
        let separators = "(?:-|~|～|到|至|—)"
        if let groups = text.captureGroups(matching: "(\\d+)\\s*\(separators)\\s*(\\d+)\\s*(个小时|小时|分钟|分|min|h)?"),
           let first = Int(groups[1]), let second = Int(groups[2]) {
            let multiplier = groups[3].contains("小时") || groups[3] == "h" ? 60 : 1
            return (max(1, min(first, second) * multiplier), max(first, second) * multiplier)
        }
        if let groups = text.captureGroups(matching: "(\\d+)\\s*(?:个)?(?:小时|h)"), let hours = Int(groups[1]) {
            return range(upTo: hours * 60)
        }
        if let groups = text.captureGroups(matching: "(\\d+)\\s*(?:分钟|分|min)"), let minutes = Int(groups[1]) {
            return range(upTo: minutes)
        }
        if text.contains("半小时") || text.contains("半个小时") {
            return range(upTo: 30)
        }
        if text.contains("一小时") || text.contains("一个小时") {
            return range(upTo: 60)
        }
        return nil
    }

    private static let chineseNumbers: [(String, String)] = [
        ("六十", "60"), ("五十", "50"), ("四十五", "45"), ("四十", "40"), ("三十", "30"),
        ("二十五", "25"), ("二十", "20"), ("十五", "15"), ("十分钟", "10分钟"), ("五分钟", "5分钟"),
        ("两个小时", "2个小时"), ("两小时", "2小时"),
    ]

    static func normalizeNumbers(_ text: String) -> String {
        chineseNumbers.reduce(text) { result, pair in
            result.replacingOccurrences(of: pair.0, with: pair.1)
        }
    }
}
