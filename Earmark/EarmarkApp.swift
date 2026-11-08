import SwiftData
import SwiftUI

@main
struct EarmarkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.orange)
        }
        .modelContainer(for: QueueItem.self)
    }
}
