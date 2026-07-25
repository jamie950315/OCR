//
//  OCRTests.swift
//  OCRTests
//
//  Created by jamie chen on 2026/3/11.
//

import Testing
import CoreGraphics
import Foundation
@testable import OCR

private final class TestCaptureOverlay: CaptureOverlay {
    var onComplete: ((CGImage?) -> Void)?
    private(set) var showCount = 0

    func show() {
        showCount += 1
    }

    func complete() {
        onComplete?(nil)
    }
}

private func makeModelDefaults() -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "OCRTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
}

struct OCRTests {
    @Test @MainActor func modelIDUsesFlashLiteByDefault() {
        let (defaults, suiteName) = makeModelDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(AppState(modelDefaults: defaults).modelId == AppState.defaultModelId)
    }

    @Test @MainActor func modelIDMigratesThePreviousDefaultToFlashLite() {
        let (defaults, suiteName) = makeModelDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("google/gemini-3-flash-preview", forKey: "modelId")

        _ = AppState(modelDefaults: defaults)

        #expect(defaults.string(forKey: "modelId") == AppState.defaultModelId)
    }

    @Test @MainActor func modelIDPreservesCustomModel() {
        let (defaults, suiteName) = makeModelDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let customModelID = "openai/gpt-5"
        defaults.set(customModelID, forKey: "modelId")

        #expect(AppState(modelDefaults: defaults).modelId == customModelID)
    }

    @Test @MainActor func modelIDAllowsChoosingThePreviousModelAfterMigration() {
        let (defaults, suiteName) = makeModelDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("google/gemini-3-flash-preview", forKey: "modelId")
        _ = AppState(modelDefaults: defaults)
        defaults.set("google/gemini-3-flash-preview", forKey: "modelId")

        #expect(AppState(modelDefaults: defaults).modelId == "google/gemini-3-flash-preview")
    }

    @Test @MainActor func duplicateCaptureShortcutIsIgnoredUntilSelectionCompletes() {
        let defaults = UserDefaults.standard
        let previousAPIKey = defaults.object(forKey: "apiKey")
        defer {
            if let previousAPIKey {
                defaults.set(previousAPIKey, forKey: "apiKey")
            } else {
                defaults.removeObject(forKey: "apiKey")
            }
        }

        let overlay = TestCaptureOverlay()
        let appState = AppState(captureOverlayFactory: { overlay })
        appState.apiKey = "test-key"

        appState.startCapture()
        appState.startCapture()

        #expect(overlay.showCount == 1)

        overlay.complete()
        appState.startCapture()

        #expect(overlay.showCount == 2)
    }
}
