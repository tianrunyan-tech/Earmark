import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "分享 → Earmark": grabs the shared text/link, drops it in the App Group
/// inbox, shows a short confirmation and closes. The app picks it up next time
/// it comes to the foreground.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await handleShare() }
    }

    @MainActor
    private func handleShare() async {
        let text = await collectSharedText()
        let parsed = text.flatMap { LinkParser.parse($0) }
        var saved = false
        if let text, parsed != nil {
            saved = ShareInbox.append(text)
        }
        show(ShareConfirmationView(saved: saved, title: parsed?.titleHint))
        try? await Task.sleep(nanoseconds: 900_000_000)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func collectSharedText() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        var parts: [String] = []
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                parts.append(text)
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL {
                    parts.append(url.absoluteString)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) as? String {
                    parts.append(text)
                }
            }
        }
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique.joined(separator: "\n")
    }

    private func show<Content: View>(_ content: Content) {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

struct ShareConfirmationView: View {
    let saved: Bool
    let title: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: saved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(saved ? Color.green : Color.orange)
            Text(saved ? "已存到待听" : "没有识别到链接")
                .font(.headline)
            if saved, let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }
}
