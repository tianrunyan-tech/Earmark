import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query(filter: #Predicate<QueueItem> { $0.isDone == true }, sort: \QueueItem.addedAt, order: .reverse)
    private var doneItems: [QueueItem]

    private var sortedItems: [QueueItem] {
        doneItems.sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if doneItems.isEmpty {
                    ContentUnavailableView(
                        "还没有听完的内容",
                        systemImage: "checkmark.circle",
                        description: Text("听完的内容会出现在这里")
                    )
                } else {
                    List {
                        ForEach(sortedItems) { item in
                            Button {
                                if let url = item.url { openURL(url) }
                            } label: {
                                QueueRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    item.isDone = false
                                    item.finishedAt = nil
                                } label: {
                                    Label("放回待听", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("已听")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
