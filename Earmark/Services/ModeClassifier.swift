import Foundation

/// First-pass guess of whether something is background listening or needs
/// attention. Keyword based for now; the user can always flip it, and an LLM
/// classifier can replace this later.
enum ModeClassifier {
    static let focusKeywords = [
        "教程", "讲解", "原理", "课程", "公开课", "讲座", "分享会", "技术", "论文", "架构",
        "算法", "编程", "代码", "深度", "解析", "复盘", "方法论", "拆解", "入门", "面试",
        "大模型", "llm", "gpt", "机器学习", "数学", "物理", "经济学", "财报", "研报", "考研",
        "tutorial", "lecture", "course", "deep dive", "explained",
    ]

    static let casualKeywords = [
        "聊天", "闲聊", "播客", "电台", "故事", "vlog", "日常", "访谈", "吐槽", "八卦",
        "相声", "脱口秀", "音乐", "歌", "读书", "随便聊", "唠嗑", "podcast", "chat", "interview",
    ]

    static func guess(title: String) -> ListenMode {
        let text = title.lowercased()
        let focusScore = focusKeywords.filter { text.contains($0) }.count
        let casualScore = casualKeywords.filter { text.contains($0) }.count
        return focusScore > casualScore ? .focus : .casual
    }
}
