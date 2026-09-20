# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Official name: "Obviously Can't Remember" (OCR)** — the package/code identifier remains `OCR`, only the display name differs.

macOS menu bar OCR application built with SwiftUI. Captures screen regions via user selection, sends images to OpenRouter API (Qwen3.8 Flash by default) for OCR, and auto-copies results to clipboard with toast notifications. Supports 8 languages with runtime switching.

## Build & Run

- **IDE**: Xcode (`.xcodeproj` based, no SPM Package.swift)
- **Build**: `xcodebuild -project OCR.xcodeproj -scheme OCR -configuration Debug build`
- **Run tests**: `xcodebuild -project OCR.xcodeproj -scheme OCR -configuration Debug test`
- **Run single test**: `xcodebuild -project OCR.xcodeproj -scheme OCR -only-testing:OCRTests/SpecificTestClass/testMethod test`
- **Platform**: macOS 26.2+ (SwiftUI lifecycle, `@main` App)

## macOS 26 API Notes

- Requires explicit `import Combine` for `@Published`
- `CGWindowListCreateImage` is unavailable — use ScreenCaptureKit (`SCScreenshotManager`)
- Use `NSApp.activate(ignoringOtherApps:)` not `forIgnoringOtherApps:`
- Use `@Environment(\.openSettings)` to open Settings scene — do NOT use `NSApp.sendAction(showSettingsWindow:)`. For accessory apps, always call `NSApp.activate(ignoringOtherApps: true)` before `openSettings()` to bring the window to front. Use a plain `Button` instead of `SettingsLink` when you need to control activation order
- Do NOT mutate `@Published` directly from a SwiftUI `Picker` binding — wrap in `DispatchQueue.main.async` to avoid "Publishing changes from within view updates" warnings

## Architecture

- `OCR/OCRApp.swift` — App entry point, `MenuBarExtra` menu bar UI, `AppDelegate` for activation policy & hotkey registration. Uses `@Environment(\.openSettings)` for programmatic settings open
- `OCR/AppState.swift` — Singleton `ObservableObject` coordinating capture→OCR→clipboard flow. Settings stored in `UserDefaults`. Uses `shouldOpenSettings` flag to trigger settings from non-SwiftUI code
  - Default model: `qwen/qwen3.8-flash`, with no routing suffix or provider override. One-time migration replaces saved previous Gemini defaults; custom model IDs and subsequent user choices are preserved.
- `OCR/HotkeyManager.swift` — Global hotkey via Carbon `RegisterEventHotKey`. Converts between `NSEvent.ModifierFlags` and Carbon modifier constants
- `OCR/ScreenCaptureOverlay.swift` — Full-screen transparent overlay windows for region selection. Uses ScreenCaptureKit (`SCScreenshotManager`) for capture. `OverlayWindow` subclass overrides `canBecomeKey` for keyboard events
- `OCR/OpenRouterService.swift` — Sends base64-encoded PNG to `POST /api/v1/chat/completions` on OpenRouter
  - OCR prompt requests GitHub-flavored Markdown for tables (escaped pipes, `<br>` for in-cell line breaks, merged content in the top-left cell only), while preserving non-table text and reading order. This is model-directed formatting, not deterministic table reconstruction.
- `OCR/SettingsView.swift` — SwiftUI `Settings` scene: API key, model ID, hotkey recorder via `NSEvent.addLocalMonitorForEvents`, launch-at-login toggle via `SMAppService`, language picker
- `OCR/ToastWindow.swift` — Floating `NSPanel` HUD for transient notifications (capture success, OCR complete, errors). Auto-dismisses with fade animation
- `OCR/LocalizationManager.swift` — Singleton `ObservableObject` with embedded translation dictionaries. Call `lm.t("key")` or `lm.t("key", arg)` for localized strings. Language persisted in UserDefaults. Inject as `@EnvironmentObject` in SwiftUI views; access via `LocalizationManager.shared` in non-SwiftUI code
- `OCR/OCR.entitlements` — App Sandbox with `com.apple.security.network.client` for API access

## Release Packaging

- Local install target: `/Applications/OCR.app`; retain the previous bundle outside the repository before replacement.
- Build Release with `ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO` for a universal macOS app, then verify both architectures and the code signature.
- Publish a DMG, zipped `.app`, and SHA-256 checksums on GitHub. Current signing uses an Apple Development certificate; releases are not notarized and may trigger Gatekeeper warnings on other Macs.
- Stage bundles outside cloud-synced folders (for example, `/tmp`); Finder/file-provider metadata can invalidate strict signature checks. Verify the app inside the final archives, not only the build output.
- Reuse still-valid OCR acceptance evidence; verify changed settings/migrations, build identity, installed version, and published asset checksums for a release.

## Supported Languages

`en`, `zh-TW`, `zh-CN`, `ja`, `ko`, `es`, `fr`, `de`

## Key Patterns

- Menu bar-only app: `NSApp.setActivationPolicy(.accessory)` in AppDelegate
- Coordinate conversion: NSView (bottom-left origin) → CG screen coords (top-left origin) for ScreenCaptureKit `sourceRect`
- Default hotkey: ⌃⌥O (Control+Option+O). Stored as Carbon keyCode/modifiers in UserDefaults
- Adding a new language: add a case to `LocalizationManager.Language`, add a `displayName`, and add its translation dictionary in `translations`
- Console messages from `AddInstanceForFactory`, `HALC_ProxyIOContext`, `FBSScene` are macOS system noise — safe to ignore
