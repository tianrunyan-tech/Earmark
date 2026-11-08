import Foundation
import SwiftData

/// One saved link in the to-listen queue. Playback happens in the original app.
@Model
final class QueueItem {
    var itemID: UUID = UUID()
    var urlString: String = ""
    var title: String = ""
    /// True while the title is a fallback like "抖音链接" that metadata may replace.
    var titleIsPlaceholder: Bool = true
    var platformRaw: String = Platform.other.rawValue
    var thumbnailURLString: String?
    var durationMinutes: Int?
    var modeRaw: String = ListenMode.casual.rawValue
    /// Once the user picks a mode by hand, automatic guesses stop overriding it.
    var modeIsUserSet: Bool = false
    var isDone: Bool = false
    var addedAt: Date = Date.now
    var finishedAt: Date?

    init(
        url: URL,
        title: String,
        titleIsPlaceholder: Bool,
        platform: Platform,
        durationMinutes: Int?,
        mode: ListenMode,
        modeIsUserSet: Bool,
        addedAt: Date = .now
    ) {
        self.itemID = UUID()
        self.urlString = url.absoluteString
        self.title = title
        self.titleIsPlaceholder = titleIsPlaceholder
        self.platformRaw = platform.rawValue
        self.durationMinutes = durationMinutes
        self.modeRaw = mode.rawValue
        self.modeIsUserSet = modeIsUserSet
        self.addedAt = addedAt
    }

    var url: URL? { URL(string: urlString) }

    var platform: Platform { Platform(rawValue: platformRaw) ?? .other }

    var mode: ListenMode {
        get { ListenMode(rawValue: modeRaw) ?? .casual }
        set { modeRaw = newValue.rawValue }
    }

    var thumbnailURL: URL? { thumbnailURLString.flatMap { URL(string: $0) } }
}
