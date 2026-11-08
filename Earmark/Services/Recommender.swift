import Foundation

struct RecommendationCandidate: Equatable {
    let id: UUID
    let minutes: Int?
    let mode: ListenMode
    let addedAt: Date
}

struct Recommendation: Equatable {
    /// Picked items, oldest saved first.
    let ids: [UUID]
    let totalMinutes: Int
    /// True if any picked item had no known duration and was counted as an estimate.
    let usesEstimates: Bool
}

/// Picks up to three items that fill the available time as fully as possible,
/// favouring things that have waited longest. Content that needs focus is only
/// offered for a dedicated listening slot.
enum Recommender {
    static let estimatedMinutes = 10
    static let maxItems = 3

    static func recommend(from candidates: [RecommendationCandidate], for intent: ListeningIntent) -> Recommendation? {
        let pool = candidates
            .filter { intent.scene.allowsFocusContent || $0.mode == .casual }
            .sorted { $0.addedAt < $1.addedAt }
        let capacity = intent.maxMinutes
        guard capacity > 0, !pool.isEmpty else { return nil }

        struct State {
            var value: Int
            var picks: [Int]
        }

        // best[count][minutes] = highest-scoring choice of `count` items totalling `minutes`.
        var best = [[State?]](
            repeating: [State?](repeating: nil, count: capacity + 1),
            count: maxItems + 1
        )
        best[0][0] = State(value: 0, picks: [])

        for (index, item) in pool.enumerated() {
            let weight = item.minutes ?? estimatedMinutes
            guard weight > 0, weight <= capacity else { continue }
            let value = score(item, weight: weight, index: index, poolSize: pool.count, scene: intent.scene)
            for count in stride(from: maxItems - 1, through: 0, by: -1) {
                for used in stride(from: capacity - weight, through: 0, by: -1) {
                    guard let state = best[count][used] else { continue }
                    let next = State(value: state.value + value, picks: state.picks + [index])
                    if let existing = best[count + 1][used + weight], existing.value >= next.value { continue }
                    best[count + 1][used + weight] = next
                }
            }
        }

        var winner: (state: State, total: Int)?
        for count in 1...maxItems {
            for used in 0...capacity {
                guard let state = best[count][used] else { continue }
                if state.value > (winner?.state.value ?? Int.min) {
                    winner = (state, used)
                }
            }
        }
        guard let winner else { return nil }

        let picked = winner.state.picks.map { pool[$0] }
        return Recommendation(
            ids: picked.map(\.id),
            totalMinutes: winner.total,
            usesEstimates: picked.contains { $0.minutes == nil }
        )
    }

    /// Filling the time dominates (100 points per minute); waiting longer, having
    /// a known duration and matching a focus slot only break ties.
    private static func score(
        _ item: RecommendationCandidate,
        weight: Int,
        index: Int,
        poolSize: Int,
        scene: ListeningScene
    ) -> Int {
        var value = weight * 100
        value += min(poolSize - index, 50)
        if item.minutes == nil { value -= 30 }
        if scene == .focusTime && item.mode == .focus { value += 60 }
        return value
    }
}
