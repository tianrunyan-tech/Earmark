# Earmark

A to-listen list for long videos you run into while scrolling. Save a link from Douyin, Bilibili, Xiaohongshu, YouTube and similar apps. When you have time (cooking, commuting, working out), the app suggests what fits and sends you back to the original app to listen.

## Current features (v0.1)

- **Save links**: use the share sheet ("分享 → Earmark") or paste a link inside the app. The app pulls out the link, platform and title from the share text automatically.
- **Metadata**: fetches title, cover and duration where it can. Bilibili gives full data, YouTube gives title and cover, and other sites fall back to the page's meta tags.
- **Two kinds of content**: "边做边听" (listen while doing something else) and "需要专注" (needs focus). The app guesses from the title and you can change it by hand.
- **"我有空，现在听什么？"**: pick a scene and a time budget, or type something like "我要做饭，大概 20-30 分钟". The app picks up to 3 items that fill the time, favouring things that have waited longest. Focus content is only suggested in "专心听" mode.
- **Listening flow**: tap an item to open it in the original app. When you come back, the app asks "听完了吗？" and can open the next one.
- **History**: listened items can be put back on the list or deleted.

## Running it

Requires Xcode 16+ and iOS 17+. The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open Earmark.xcodeproj
```

1. In Xcode, select your Team under **Signing & Capabilities** for both the `Earmark` and `EarmarkShare` targets. You can also put your Team ID in `DEVELOPMENT_TEAM` in `project.yml`.
2. If the bundle ID `com.tianrunyan.earmark` is already taken, change the prefix in `project.yml`. Also change the App Group (`group.com.tianrunyan.earmark`) in both `.entitlements` files and in `Shared/ShareInbox.swift` so all three match.
3. Choose the `Earmark` scheme and run it on a device or simulator. Press ⌘U to run the tests.

Re-run `xcodegen generate` after adding or removing files. The `.xcodeproj` is generated and is not committed.

## Code layout

```
Earmark/            App: SwiftUI views, SwiftData model, recommendation and parsing logic
Shared/             Code shared by the app and the share extension (link parsing, App Group inbox)
ShareExtension/     Share-sheet extension
EarmarkTests/       Unit tests (Swift Testing)
```
