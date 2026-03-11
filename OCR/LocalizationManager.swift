import Combine
import Foundation

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case traditionalChinese = "zh-TW"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .english: return "English"
            case .traditionalChinese: return "繁體中文"
            }
        }
    }

    @Published private(set) var language: Language

    func setLanguage(_ lang: Language) {
        DispatchQueue.main.async { [weak self] in
            self?.language = lang
            UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-TW"
        language = Language(rawValue: saved) ?? .traditionalChinese
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        let template = translations[language.rawValue]?[key]
            ?? translations["en"]?[key]
            ?? key
        return args.isEmpty ? template : String(format: template, arguments: args)
    }

    // MARK: - Translations

    private let translations: [String: [String: String]] = [
        "en": [
            // Menu
            "menu.ocr_capture":     "OCR Capture (%@)",
            "menu.processing":      "Recognizing...",
            "menu.settings":        "Settings...",
            "menu.quit":            "Quit",

            // Status / Toast
            "status.set_api_key":   "Please set API Key first",
            "status.processing":    "Recognizing...",
            "status.copied":        "Copied to clipboard",
            "status.no_text":       "No text detected",
            "status.error":         "Error: %@",

            "toast.capture_success": "Screenshot captured, recognizing...",
            "toast.ocr_complete":    "OCR complete, copied to clipboard",
            "toast.no_text":         "No text detected",
            "toast.ocr_failed":      "Recognition failed",

            // Settings
            "settings.api_section":        "API Settings",
            "settings.hotkey_section":     "Hotkey",
            "settings.language_section":   "Language",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "Model ID",
            "settings.model_hint":         "Default: google/gemini-2.5-pro-preview",
            "settings.hotkey_label":       "OCR Capture Hotkey:",
            "settings.hotkey_hint":        "Must include at least one modifier key (⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command)",
            "settings.press_shortcut":     "Press shortcut keys...",
            "settings.language_label":     "Language:",

            // Alert
            "alert.screen_capture_title":   "Cannot Capture Screen",
            "alert.screen_capture_message": "Please allow this app in System Settings → Privacy & Security → Screen Recording.",
            "alert.open_settings":          "Open System Settings",
            "alert.cancel":                 "Cancel",

            // Errors
            "error.image_conversion": "Image conversion failed",
            "error.invalid_response": "Invalid API response",
            "error.no_content":       "No content in API response",
        ],
        "zh-TW": [
            // Menu
            "menu.ocr_capture":     "OCR 截圖 (%@)",
            "menu.processing":      "正在辨識中...",
            "menu.settings":        "設定...",
            "menu.quit":            "結束",

            // Status / Toast
            "status.set_api_key":   "請先設定 API Key",
            "status.processing":    "正在辨識...",
            "status.copied":        "已複製到剪貼簿",
            "status.no_text":       "未偵測到文字",
            "status.error":         "錯誤：%@",

            "toast.capture_success": "截圖成功，正在辨識...",
            "toast.ocr_complete":    "OCR 完成，已複製到剪貼簿",
            "toast.no_text":         "未偵測到文字",
            "toast.ocr_failed":      "辨識失敗",

            // Settings
            "settings.api_section":        "API 設定",
            "settings.hotkey_section":     "快捷鍵",
            "settings.language_section":   "語言",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "模型 ID",
            "settings.model_hint":         "預設：google/gemini-2.5-pro-preview",
            "settings.hotkey_label":       "OCR 截圖快捷鍵：",
            "settings.hotkey_hint":        "需包含至少一個修飾鍵（⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command）",
            "settings.press_shortcut":     "請按下快捷鍵組合...",
            "settings.language_label":     "語言：",

            // Alert
            "alert.screen_capture_title":   "無法截取螢幕",
            "alert.screen_capture_message": "請在「系統設定」>「隱私權與安全性」>「螢幕錄影」中允許此應用程式。",
            "alert.open_settings":          "開啟系統設定",
            "alert.cancel":                 "取消",

            // Errors
            "error.image_conversion": "圖片轉換失敗",
            "error.invalid_response": "無效的 API 回應",
            "error.no_content":       "API 回應中沒有內容",
        ],
    ]
}
