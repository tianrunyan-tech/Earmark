import SwiftUI

/// "我有空，现在听什么？" — pick a scene and a time budget (or just type it),
/// get up to three items that fit.
struct RecommendView: View {
    let queue: [QueueItem]
    let onStart: ([QueueItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var request = ""
    @State private var scene: ListeningScene = .cooking
    @State private var minMinutes = 21
    @State private var maxMinutes = 30
    @State private var didNotUnderstand = false

    private static let timePresets = [10, 15, 20, 30, 45, 60]

    private var intent: ListeningIntent {
        ListeningIntent(minMinutes: minMinutes, maxMinutes: maxMinutes, scene: scene)
    }

    private var recommendation: Recommendation? {
        let candidates = queue.map {
            RecommendationCandidate(id: $0.itemID, minutes: $0.durationMinutes, mode: $0.mode, addedAt: $0.addedAt)
        }
        return Recommender.recommend(from: candidates, for: intent)
    }

    private func items(for recommendation: Recommendation) -> [QueueItem] {
        recommendation.ids.compactMap { id in queue.first { $0.itemID == id } }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("比如：我要做饭，大概 20-30 分钟", text: $request)
                            .submitLabel(.done)
                            .onSubmit(applyRequest)
                        Button("好", action: applyRequest)
                            .disabled(request.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    if didNotUnderstand {
                        Text("没太看懂，可以直接点下面的场景和时间")
                    }
                }

                Section("在做什么") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ListeningScene.allCases) { option in
                                Chip(title: option.label, systemImage: option.symbol, isSelected: scene == option) {
                                    scene = option
                                }
                            }
                        }
                    }
                }

                Section("有多少时间") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.timePresets, id: \.self) { preset in
                                Chip(title: "\(preset) 分钟", isSelected: maxMinutes == preset) {
                                    let range = IntentParser.range(upTo: preset)
                                    minMinutes = range.0
                                    maxMinutes = range.1
                                }
                            }
                        }
                    }
                }

                resultSection
            }
            .navigationTitle("现在听什么")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let recommendation {
                    let picked = items(for: recommendation)
                    Button {
                        dismiss()
                        onStart(picked)
                    } label: {
                        Label("开始听（\(picked.count) 条）", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let recommendation {
            Section {
                ForEach(items(for: recommendation)) { item in
                    QueueRow(item: item)
                }
            } header: {
                Text("推荐 · 共约 \(recommendation.totalMinutes) 分钟")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if recommendation.totalMinutes < minMinutes {
                        Text("没有刚好能填满的组合，这是最接近的。")
                    }
                    if recommendation.usesEstimates {
                        Text("有的内容时长未知，按 \(Recommender.estimatedMinutes) 分钟估算。")
                    }
                    if !scene.allowsFocusContent {
                        Text("「\(scene.label)」时只推荐可以边做边听的内容。")
                    }
                }
            }
        } else {
            Section {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyMessage: String {
        if !scene.allowsFocusContent && !queue.contains(where: { $0.mode == .casual }) {
            return "待听列表里没有适合边做边听的内容，试试「专心听」。"
        }
        return "没有 \(maxMinutes) 分钟以内能听完的内容，试试更长的时间。"
    }

    private func applyRequest() {
        guard let parsed = IntentParser.parse(request) else {
            didNotUnderstand = true
            return
        }
        didNotUnderstand = false
        scene = parsed.scene
        minMinutes = parsed.minMinutes
        maxMinutes = parsed.maxMinutes
    }
}
