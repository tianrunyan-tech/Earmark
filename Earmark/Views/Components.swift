import SwiftUI

struct QueueRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(url: item.thumbnailURL, platform: item.platform)
                .frame(width: 72, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(item.platform.displayName)
                    if let minutes = item.durationMinutes {
                        Text("·")
                        Text("\(minutes) 分钟")
                    }
                    ModeTag(mode: item.mode)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct ModeTag: View {
    let mode: ListenMode

    var body: some View {
        Text(mode.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(mode.color)
            .background(mode.color.opacity(0.15), in: Capsule())
    }
}

struct Thumbnail: View {
    let url: URL?
    let platform: Platform

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemFill))
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        Text(String(platform.displayName.prefix(2)))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

struct Chip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.orange : Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct DurationPicker: View {
    @Binding var minutes: Int?

    private static let presets = [5, 10, 20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "不确定", isSelected: minutes == nil) { minutes = nil }
                    ForEach(Self.presets, id: \.self) { preset in
                        Chip(title: "\(preset) 分钟", isSelected: minutes == preset) { minutes = preset }
                    }
                }
            }
            if let current = minutes {
                Stepper(
                    "约 \(current) 分钟",
                    value: Binding(get: { current }, set: { minutes = $0 }),
                    in: 1...240
                )
            }
        }
    }
}
