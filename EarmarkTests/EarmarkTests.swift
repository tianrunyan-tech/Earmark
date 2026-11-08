import Foundation
import Testing
@testable import Earmark

struct LinkParserTests {
    @Test func bilibiliShareText() throws {
        let parsed = try #require(LinkParser.parse("【我是标题-哔哩哔哩】 https://b23.tv/abc123"))
        #expect(parsed.platform == .bilibili)
        #expect(parsed.url.absoluteString == "https://b23.tv/abc123")
        #expect(parsed.titleHint == "我是标题")
    }

    @Test func douyinShareText() throws {
        let text = "7.69 复制打开抖音，看看【小王的作品】三分钟讲清楚复利 # 理财 https://v.douyin.com/iRNBho6u/ a@G.vs 07/12 ZzX:/"
        let parsed = try #require(LinkParser.parse(text))
        #expect(parsed.platform == .douyin)
        #expect(parsed.url.host() == "v.douyin.com")
        #expect(parsed.titleHint == "三分钟讲清楚复利")
    }

    @Test func xiaohongshuShareText() throws {
        let text = "一周搞懂 Transformer 原理 http://xhslink.com/a/AbCd 复制本条信息，打开【小红书】App查看精彩内容！"
        let parsed = try #require(LinkParser.parse(text))
        #expect(parsed.platform == .xiaohongshu)
        #expect(parsed.titleHint == "一周搞懂 Transformer 原理")
    }

    @Test func bareLinkHasNoTitleHint() throws {
        let parsed = try #require(LinkParser.parse("https://youtu.be/dQw4w9WgXcQ"))
        #expect(parsed.platform == .youtube)
        #expect(parsed.titleHint == nil)
    }

    @Test func textWithoutLink() {
        #expect(LinkParser.parse("今天天气不错") == nil)
    }
}

struct IntentParserTests {
    @Test func cookingWithRange() throws {
        let intent = try #require(IntentParser.parse("我要做饭，大概20-30分钟"))
        #expect(intent == ListeningIntent(minMinutes: 20, maxMinutes: 30, scene: .cooking))
    }

    @Test func commuteHalfHour() throws {
        let intent = try #require(IntentParser.parse("通勤半小时"))
        #expect(intent == ListeningIntent(minMinutes: 21, maxMinutes: 30, scene: .commute))
    }

    @Test func chineseNumerals() throws {
        let intent = try #require(IntentParser.parse("跑步四十分钟"))
        #expect(intent.scene == .exercise)
        #expect(intent.maxMinutes == 40)
    }

    @Test func unrelatedTextIsNotUnderstood() {
        #expect(IntentParser.parse("你好") == nil)
    }
}

struct RecommenderTests {
    private func candidate(_ minutes: Int?, _ mode: ListenMode = .casual, daysAgo: Double) -> RecommendationCandidate {
        RecommendationCandidate(
            id: UUID(),
            minutes: minutes,
            mode: mode,
            addedAt: Date(timeIntervalSince1970: 1_700_000_000 - daysAgo * 86_400)
        )
    }

    @Test func fillsTheTimeWindow() throws {
        let a = candidate(12, daysAgo: 4)
        let b = candidate(15, daysAgo: 3)
        let c = candidate(25, daysAgo: 2)
        let d = candidate(8, daysAgo: 1)
        let intent = ListeningIntent(minMinutes: 20, maxMinutes: 30, scene: .chores)

        let result = try #require(Recommender.recommend(from: [d, c, b, a], for: intent))
        #expect(result.ids == [a.id, b.id])
        #expect(result.totalMinutes == 27)
        #expect(result.usesEstimates == false)
    }

    @Test func handsBusyScenesSkipFocusContent() throws {
        let focus = candidate(20, .focus, daysAgo: 5)
        let casual = candidate(10, daysAgo: 1)
        let intent = ListeningIntent(minMinutes: 14, maxMinutes: 20, scene: .cooking)

        let result = try #require(Recommender.recommend(from: [focus, casual], for: intent))
        #expect(result.ids == [casual.id])
    }

    @Test func focusSlotCanUseFocusContent() throws {
        let focus = candidate(20, .focus, daysAgo: 5)
        let intent = ListeningIntent(minMinutes: 14, maxMinutes: 20, scene: .focusTime)

        let result = try #require(Recommender.recommend(from: [focus], for: intent))
        #expect(result.ids == [focus.id])
    }

    @Test func unknownDurationsAreEstimated() throws {
        let unknown = candidate(nil, daysAgo: 1)
        let intent = ListeningIntent(minMinutes: 7, maxMinutes: 10, scene: .chores)

        let result = try #require(Recommender.recommend(from: [unknown], for: intent))
        #expect(result.totalMinutes == Recommender.estimatedMinutes)
        #expect(result.usesEstimates)
    }

    @Test func nothingFits() {
        let long = candidate(90, daysAgo: 1)
        let intent = ListeningIntent(minMinutes: 7, maxMinutes: 10, scene: .chores)
        #expect(Recommender.recommend(from: [long], for: intent) == nil)
    }
}

struct ModeClassifierTests {
    @Test func technicalTalkNeedsFocus() {
        #expect(ModeClassifier.guess(title: "Transformer 架构原理讲解") == .focus)
    }

    @Test func chattyVlogIsCasual() {
        #expect(ModeClassifier.guess(title: "周末vlog 和朋友聊天") == .casual)
    }
}
