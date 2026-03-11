import SwiftUI
import Combine
import Carbon

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isProcessing = false
    @Published var statusMessage: String?
    @Published var shouldOpenSettings = false

    private let hotkeyManager = HotkeyManager()
    private var captureOverlay: ScreenCaptureOverlay?

    // MARK: - Settings (UserDefaults backed)

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "apiKey")
            objectWillChange.send()
        }
    }

    var modelId: String {
        get { UserDefaults.standard.string(forKey: "modelId") ?? "google/gemini-2.5-pro-preview" }
        set { UserDefaults.standard.set(newValue, forKey: "modelId") }
    }

    var hotkeyKeyCode: UInt32 {
        get {
            if UserDefaults.standard.object(forKey: "hotkeyKeyCode") != nil {
                return UInt32(UserDefaults.standard.integer(forKey: "hotkeyKeyCode"))
            }
            return 31 // Default: O
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    var hotkeyModifiers: UInt32 {
        get {
            if UserDefaults.standard.object(forKey: "hotkeyModifiers") != nil {
                return UInt32(UserDefaults.standard.integer(forKey: "hotkeyModifiers"))
            }
            return UInt32(controlKey | optionKey) // Default: ⌃⌥
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyModifiers") }
    }

    var hotkeyDisplayString: String {
        HotkeyManager.displayString(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
    }

    // MARK: - Hotkey

    func registerHotkey() {
        hotkeyManager.register(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers) { [weak self] in
            self?.startCapture()
        }
    }

    // MARK: - Screen Capture

    func startCapture() {
        guard !isProcessing else { return }
        guard !apiKey.isEmpty else {
            statusMessage = LocalizationManager.shared.t("status.set_api_key")
            shouldOpenSettings = true
            return
        }

        captureOverlay = ScreenCaptureOverlay()
        captureOverlay?.onComplete = { [weak self] image in
            guard let self = self else { return }
            self.captureOverlay = nil
            if let image = image {
                ToastWindow.shared.show(icon: "camera.viewfinder", message: LocalizationManager.shared.t("toast.capture_success"))
                self.performOCR(on: image)
            }
        }
        captureOverlay?.show()
    }

    // MARK: - OCR

    private func performOCR(on image: CGImage) {
        isProcessing = true
        statusMessage = LocalizationManager.shared.t("status.processing")

        Task {
            do {
                let text = try await OpenRouterService.performOCR(
                    image: image,
                    apiKey: apiKey,
                    model: modelId
                )

                await MainActor.run {
                    let lm = LocalizationManager.shared
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        statusMessage = lm.t("status.no_text")
                        ToastWindow.shared.show(icon: "text.magnifyingglass", message: lm.t("toast.no_text"))
                    } else {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        statusMessage = lm.t("status.copied")
                        NSSound(named: .init("Submarine"))?.play()
                        ToastWindow.shared.show(icon: "checkmark.circle.fill", message: lm.t("toast.ocr_complete"))
                    }
                    isProcessing = false
                    clearStatusAfterDelay()
                }
            } catch {
                await MainActor.run {
                    let lm = LocalizationManager.shared
                    statusMessage = lm.t("status.error", error.localizedDescription)
                    isProcessing = false
                    ToastWindow.shared.show(icon: "xmark.circle.fill", message: lm.t("toast.ocr_failed"), duration: 3)
                    clearStatusAfterDelay(seconds: 5)
                }
            }
        }
    }

    private func clearStatusAfterDelay(seconds: Double = 3) {
        let currentMessage = statusMessage
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.statusMessage == currentMessage {
                self?.statusMessage = nil
            }
        }
    }

}
