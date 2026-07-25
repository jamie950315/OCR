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

struct OCRTests {
    @Test @MainActor func modelIDUsesFlashLiteByDefault() {
        let defaults = UserDefaults.standard
        let previousModelID = defaults.object(forKey: "modelId")
        defaults.removeObject(forKey: "modelId")
        defer {
            if let previousModelID {
                defaults.set(previousModelID, forKey: "modelId")
            } else {
                defaults.removeObject(forKey: "modelId")
            }
        }

        #expect(AppState().modelId == "google/gemini-3.5-flash-lite")
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
