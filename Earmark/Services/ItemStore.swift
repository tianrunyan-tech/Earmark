import Foundation
import SwiftData

@MainActor
enum ItemStore {
    enum AddResult {
        case added(QueueItem)
        case duplicate(QueueItem)
        case invalid
    }

    /// Creates a queue item from share text or a bare link, then fills in
    /// metadata in the background.
    @discardableResult
    static func add(
        text: String,
        title: String? = nil,
        minutes: Int? = nil,
        mode: ListenMode? = nil,
        addedAt: Date = .now,
        in context: ModelContext
    ) -> AddResult {
        guard let parsed = LinkParser.parse(text) else { return .invalid }

        let urlString = parsed.url.absoluteString
        let descriptor = FetchDescriptor<QueueItem>(
            predicate: #Predicate { $0.urlString == urlString && $0.isDone == false }
        )
        if let existing = try? context.fetch(descriptor).first {
            return .duplicate(existing)
        }

        let typedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownTitle = (typedTitle?.isEmpty == false ? typedTitle : nil) ?? parsed.titleHint
        let item = QueueItem(
            url: parsed.url,
            title: knownTitle ?? "\(parsed.platform.displayName)链接",
            titleIsPlaceholder: knownTitle == nil,
            platform: parsed.platform,
            durationMinutes: minutes,
            mode: mode ?? ModeClassifier.guess(title: knownTitle ?? ""),
            modeIsUserSet: mode != nil,
            addedAt: addedAt
        )
        context.insert(item)
        refreshMetadata(item)
        return .added(item)
    }

    /// Pulls in everything the share extension saved while the app was closed.
    @discardableResult
    static func importInbox(into context: ModelContext) -> Int {
        var added = 0
        for share in ShareInbox.drain() {
            if case .added = add(text: share.text, addedAt: share.sharedAt, in: context) {
                added += 1
            }
        }
        return added
    }

    static func refreshMetadata(_ item: QueueItem) {
        guard let url = item.url else { return }
        let platform = item.platform
        Task {
            let metadata = await MetadataFetcher.fetch(url: url, platform: platform)
            guard item.modelContext != nil else { return } // deleted meanwhile
            if item.titleIsPlaceholder, let title = metadata.title, !title.isEmpty {
                item.title = title
                item.titleIsPlaceholder = false
            }
            if item.thumbnailURLString == nil {
                item.thumbnailURLString = metadata.thumbnailURL?.absoluteString
            }
            if item.durationMinutes == nil, let seconds = metadata.durationSeconds, seconds > 0 {
                item.durationMinutes = max(1, Int((Double(seconds) / 60).rounded()))
            }
            if !item.modeIsUserSet {
                item.mode = ModeClassifier.guess(title: item.title)
            }
        }
    }

    static func markDone(_ item: QueueItem) {
        item.isDone = true
        item.finishedAt = .now
    }
}
