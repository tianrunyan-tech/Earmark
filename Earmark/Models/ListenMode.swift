import SwiftUI

/// Whether a piece of content can be listened to while doing something else.
enum ListenMode: String, Codable, CaseIterable, Identifiable {
    case casual
    case focus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: "边做边听"
        case .focus: "需要专注"
        }
    }

    var symbol: String {
        switch self {
        case .casual: "figure.walk"
        case .focus: "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .casual: .teal
        case .focus: .purple
        }
    }
}
