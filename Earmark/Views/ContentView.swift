import SwiftData
import SwiftUI

enum ModeFilter: String, CaseIterable, Identifiable {
    case all, casual, focus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "全部"
        case .casual: ListenMode.casual.label
        case .focus: ListenMode.focus.label
        }
    }

    func includes(_ mode: ListenMode) -> Bool {
        switch self {
        case .all: true
        case .casual: mode == .casual
        case .focus: mode == .focus
        }
    }
}

/// A run of items the user started listening to. When they come back from the
/// original app we ask whether they finished, and offer the next one.
struct ListeningSession {
    var itemIDs: [UUID] = []
    var leftApp = false
    var isAsking = false

    var isActive: Bool { !itemIDs.isEmpty }

    func current(in items: [QueueItem]) -> QueueItem? {
        guard let id = itemIDs.first else { return nil }
        return items.first { $0.itemID == id }
    }

    func next(in items: [QueueItem]) -> QueueItem? {
        for id in itemIDs.dropFirst() {
            if let item = items.first(where: { $0.itemID == id }) { return item }
        }
        return nil
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @Query(filter: #Predicate<QueueItem> { $0.isDone == false }, sort: \QueueItem.addedAt, order: .reverse)
    private var queue: [QueueItem]

    @State private var filter: ModeFilter = .all
    @State private var showingAdd = false
    @State private var showingRecommend = false
    @State private var showingHistory = false
    @State private var editingItem: QueueItem?
    @State private var session = ListeningSession()
    @State private var toast: String?

    private var visibleItems: [QueueItem] {
        queue.filter { filter.includes($0.mode) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if queue.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("待听")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("已听记录")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加链接")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !queue.isEmpty {
                    recommendButton
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddItemView()
        }
        .sheet(isPresented: $showingRecommend) {
            RecommendView(queue: queue) { items in
                startSession(items)
            }
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .sheet(item: $editingItem) { item in
            EditItemView(item: item)
        }
        .alert("听完了吗？", isPresented: $session.isAsking, presenting: session.current(in: queue)) { item in
            if let next = session.next(in: queue) {
                Button("听完了，下一条") {
                    ItemStore.markDone(item)
                    session.itemIDs.removeFirst()
                    open(next)
                }
            }
            Button("听完了") {
                ItemStore.markDone(item)
                session = ListeningSession()
            }
            Button("还没听完", role: .cancel) {
                session = ListeningSession()
            }
        } message: { item in
            Text(item.title)
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handle(phase)
        }
        .task {
            importFromShareSheet()
        }
    }

    // MARK: Sections

    private var list: some View {
        List {
            Section {
                summaryHeader
                Picker("筛选", selection: $filter) {
                    ForEach(ModeFilter.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowSeparator(.hidden)

            Section {
                ForEach(visibleItems) { item in
                    Button {
                        startSession([item])
                    } label: {
                        QueueRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            ItemStore.markDone(item)
                        } label: {
                            Label("已听", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(item)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            editingItem = item
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button {
                            item.mode = item.mode == .casual ? .focus : .casual
                            item.modeIsUserSet = true
                        } label: {
                            Label(
                                item.mode == .casual ? "改为需要专注" : "改为边做边听",
                                systemImage: "arrow.left.arrow.right"
                            )
                        }
                        Button {
                            ItemStore.markDone(item)
                        } label: {
                            Label("标记已听", systemImage: "checkmark.circle")
                        }
                    }
                }
            } footer: {
                if visibleItems.isEmpty {
                    Text("这个分类下暂时没有内容")
                } else {
                    Text("点一条跳回原 App 播放 · 右滑标记已听 · 长按编辑")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var summaryHeader: some View {
        let knownMinutes = queue.compactMap(\.durationMinutes).reduce(0, +)
        let unknownCount = queue.filter { $0.durationMinutes == nil }.count
        let detail = unknownCount == 0
            ? "共约 \(knownMinutes) 分钟"
            : "已知时长约 \(knownMinutes) 分钟 · \(unknownCount) 条时长未知"
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(queue.count) 条待听")
                .font(.title2.bold())
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var recommendButton: some View {
        Button {
            showingRecommend = true
        } label: {
            Label("我有空，现在听什么？", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有待听内容", systemImage: "headphones")
        } description: {
            Text("在抖音、B站、小红书里点「分享」→「Earmark」，\n或者复制链接后点右上角 ＋")
        } actions: {
            Button("添加链接") {
                showingAdd = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Actions

    private func startSession(_ items: [QueueItem]) {
        guard let first = items.first else { return }
        session = ListeningSession(itemIDs: items.map(\.itemID))
        open(first)
    }

    private func open(_ item: QueueItem) {
        guard let url = item.url else { return }
        session.leftApp = false
        openURL(url)
    }

    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .background:
            if session.isActive {
                session.leftApp = true
            }
        case .active:
            importFromShareSheet()
            if session.isActive && session.leftApp {
                session.leftApp = false
                session.isAsking = true
            }
        default:
            break
        }
    }

    private func importFromShareSheet() {
        let added = ItemStore.importInbox(into: context)
        if added > 0 {
            showToast("新收进 \(added) 条待听")
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                if toast == message { toast = nil }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: QueueItem.self, inMemory: true)
}
