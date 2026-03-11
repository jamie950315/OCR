# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS menu bar OCR application built with SwiftUI. Captures screen regions via user selection, sends images to OpenRouter API (Gemini model) for OCR, and auto-copies results to clipboard with toast notifications.

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
- Use `SettingsLink` and `@Environment(\.openSettings)` to open Settings scene — do NOT use `NSApp.sendAction(showSettingsWindow:)`

## Architecture

- `OCR/OCRApp.swift` — App entry point, `MenuBarExtra` menu bar UI, `AppDelegate` for activation policy & hotkey registration. Uses `@Environment(\.openSettings)` for programmatic settings open
- `OCR/AppState.swift` — Singleton `ObservableObject` coordinating capture→OCR→clipboard flow. Settings stored in `UserDefaults`. Uses `shouldOpenSettings` flag to trigger settings from non-SwiftUI code
- `OCR/HotkeyManager.swift` — Global hotkey via Carbon `RegisterEventHotKey`. Converts between `NSEvent.ModifierFlags` and Carbon modifier constants
- `OCR/ScreenCaptureOverlay.swift` — Full-screen transparent overlay windows for region selection. Uses ScreenCaptureKit (`SCScreenshotManager`) for capture. `OverlayWindow` subclass overrides `canBecomeKey` for keyboard events
- `OCR/OpenRouterService.swift` — Sends base64-encoded PNG to `POST /api/v1/chat/completions` on OpenRouter
- `OCR/SettingsView.swift` — SwiftUI `Settings` scene: API key, model ID, hotkey recorder via `NSEvent.addLocalMonitorForEvents`
- `OCR/ToastWindow.swift` — Floating `NSPanel` HUD for transient notifications (capture success, OCR complete, errors). Auto-dismisses with fade animation
- `OCR/OCR.entitlements` — App Sandbox with `com.apple.security.network.client` for API access

## Key Patterns

- Menu bar-only app: `NSApp.setActivationPolicy(.accessory)` in AppDelegate
- Coordinate conversion: NSView (bottom-left origin) → CG screen coords (top-left origin) for ScreenCaptureKit `sourceRect`
- Default hotkey: ⌃⌥O (Control+Option+O). Stored as Carbon keyCode/modifiers in UserDefaults
- Console messages from `AddInstanceForFactory`, `HALC_ProxyIOContext`, `FBSScene` are macOS system noise — safe to ignore
