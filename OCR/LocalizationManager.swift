import Combine
import Foundation

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    enum Language: String, CaseIterable, Identifiable {
        case english           = "en"
        case simplifiedChinese = "zh-CN"
        case traditionalChinese = "zh-TW"
        case japanese          = "ja"
        case korean            = "ko"
        case spanish           = "es"
        case french            = "fr"
        case german            = "de"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .english:            return "English"
            case .simplifiedChinese:  return "简体中文"
            case .traditionalChinese: return "繁體中文"
            case .japanese:           return "日本語"
            case .korean:             return "한국어"
            case .spanish:            return "Español"
            case .french:             return "Français"
            case .german:             return "Deutsch"
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
            "menu.ocr_capture":     "OCR Capture (%@)",
            "menu.processing":      "Recognizing...",
            "menu.settings":        "Settings...",
            "menu.quit":            "Quit",
            "status.set_api_key":   "Please set API Key first",
            "status.processing":    "Recognizing...",
            "status.copied":        "Copied to clipboard",
            "status.no_text":       "No text detected",
            "status.error":         "Error: %@",
            "toast.capture_success": "Screenshot captured, recognizing...",
            "toast.ocr_complete":    "OCR complete, copied to clipboard",
            "toast.no_text":         "No text detected",
            "toast.ocr_failed":      "Recognition failed",
            "settings.api_section":        "API Settings",
            "settings.hotkey_section":     "Hotkey",
            "settings.language_section":   "Language",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "Model ID",
            "settings.model_hint":         "Default: google/gemini-3-flash-preview",
            "settings.hotkey_label":       "OCR Capture Hotkey:",
            "settings.hotkey_hint":        "Must include at least one modifier key (⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command)",
            "settings.press_shortcut":     "Press shortcut keys...",
            "settings.language_label":     "Language:",
            "alert.screen_capture_title":   "Cannot Capture Screen",
            "alert.screen_capture_message": "Please allow this app in System Settings → Privacy & Security → Screen Recording.",
            "alert.open_settings":          "Open System Settings",
            "alert.cancel":                 "Cancel",
            "error.image_conversion": "Image conversion failed",
            "error.invalid_response": "Invalid API response",
            "error.no_content":       "No content in API response",
        ],
        "zh-TW": [
            "menu.ocr_capture":     "OCR 截圖 (%@)",
            "menu.processing":      "正在辨識中...",
            "menu.settings":        "設定...",
            "menu.quit":            "結束",
            "status.set_api_key":   "請先設定 API Key",
            "status.processing":    "正在辨識...",
            "status.copied":        "已複製到剪貼簿",
            "status.no_text":       "未偵測到文字",
            "status.error":         "錯誤：%@",
            "toast.capture_success": "截圖成功，正在辨識...",
            "toast.ocr_complete":    "OCR 完成，已複製到剪貼簿",
            "toast.no_text":         "未偵測到文字",
            "toast.ocr_failed":      "辨識失敗",
            "settings.api_section":        "API 設定",
            "settings.hotkey_section":     "快捷鍵",
            "settings.language_section":   "語言",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "模型 ID",
            "settings.model_hint":         "預設：google/gemini-3-flash-preview",
            "settings.hotkey_label":       "OCR 截圖快捷鍵：",
            "settings.hotkey_hint":        "需包含至少一個修飾鍵（⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command）",
            "settings.press_shortcut":     "請按下快捷鍵組合...",
            "settings.language_label":     "語言：",
            "alert.screen_capture_title":   "無法截取螢幕",
            "alert.screen_capture_message": "請在「系統設定」>「隱私權與安全性」>「螢幕錄影」中允許此應用程式。",
            "alert.open_settings":          "開啟系統設定",
            "alert.cancel":                 "取消",
            "error.image_conversion": "圖片轉換失敗",
            "error.invalid_response": "無效的 API 回應",
            "error.no_content":       "API 回應中沒有內容",
        ],
        "zh-CN": [
            "menu.ocr_capture":     "OCR 截图 (%@)",
            "menu.processing":      "正在识别...",
            "menu.settings":        "设置...",
            "menu.quit":            "退出",
            "status.set_api_key":   "请先设置 API Key",
            "status.processing":    "正在识别...",
            "status.copied":        "已复制到剪贴板",
            "status.no_text":       "未检测到文字",
            "status.error":         "错误：%@",
            "toast.capture_success": "截图成功，正在识别...",
            "toast.ocr_complete":    "OCR 完成，已复制到剪贴板",
            "toast.no_text":         "未检测到文字",
            "toast.ocr_failed":      "识别失败",
            "settings.api_section":        "API 设置",
            "settings.hotkey_section":     "快捷键",
            "settings.language_section":   "语言",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "模型 ID",
            "settings.model_hint":         "默认：google/gemini-3-flash-preview",
            "settings.hotkey_label":       "OCR 截图快捷键：",
            "settings.hotkey_hint":        "需包含至少一个修饰键（⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command）",
            "settings.press_shortcut":     "请按下快捷键组合...",
            "settings.language_label":     "语言：",
            "alert.screen_capture_title":   "无法截取屏幕",
            "alert.screen_capture_message": "请在「系统设置」>「隐私与安全性」>「屏幕录制」中允许此应用。",
            "alert.open_settings":          "打开系统设置",
            "alert.cancel":                 "取消",
            "error.image_conversion": "图片转换失败",
            "error.invalid_response": "无效的 API 响应",
            "error.no_content":       "API 响应中没有内容",
        ],
        "ja": [
            "menu.ocr_capture":     "OCR キャプチャ (%@)",
            "menu.processing":      "認識中...",
            "menu.settings":        "設定...",
            "menu.quit":            "終了",
            "status.set_api_key":   "先に API キーを設定してください",
            "status.processing":    "認識中...",
            "status.copied":        "クリップボードにコピーしました",
            "status.no_text":       "テキストが検出されませんでした",
            "status.error":         "エラー: %@",
            "toast.capture_success": "スクリーンショットをキャプチャしました、認識中...",
            "toast.ocr_complete":    "OCR 完了、クリップボードにコピーしました",
            "toast.no_text":         "テキストが検出されませんでした",
            "toast.ocr_failed":      "認識に失敗しました",
            "settings.api_section":        "API 設定",
            "settings.hotkey_section":     "ホットキー",
            "settings.language_section":   "言語",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "Model ID",
            "settings.model_hint":         "デフォルト: google/gemini-3-flash-preview",
            "settings.hotkey_label":       "OCR キャプチャ ホットキー:",
            "settings.hotkey_hint":        "少なくとも 1 つの修飾キー (⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command) を含める必要があります",
            "settings.press_shortcut":     "ショートカットキーを押してください...",
            "settings.language_label":     "言語:",
            "alert.screen_capture_title":   "スクリーンをキャプチャできません",
            "alert.screen_capture_message": "システム設定 → プライバシーとセキュリティ → スクリーン録画 でこのアプリを許可してください。",
            "alert.open_settings":          "システム設定を開く",
            "alert.cancel":                 "キャンセル",
            "error.image_conversion": "画像の変換に失敗しました",
            "error.invalid_response": "不正な API レスポンス",
            "error.no_content":       "API レスポンスにコンテンツがありません",
        ],
        "ko": [
            "menu.ocr_capture":     "OCR 캡처 (%@)",
            "menu.processing":      "인식 중...",
            "menu.settings":        "설정...",
            "menu.quit":            "종료",
            "status.set_api_key":   "먼저 API 키를 설정하세요",
            "status.processing":    "인식 중...",
            "status.copied":        "클립보드에 복사됨",
            "status.no_text":       "감지된 텍스트 없음",
            "status.error":         "오류: %@",
            "toast.capture_success": "스크린샷 캡처됨, 인식 중...",
            "toast.ocr_complete":    "OCR 완료, 클립보드에 복사됨",
            "toast.no_text":         "감지된 텍스트 없음",
            "toast.ocr_failed":      "인식 실패",
            "settings.api_section":        "API 설정",
            "settings.hotkey_section":     "단축키",
            "settings.language_section":   "언어",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "Model ID",
            "settings.model_hint":         "기본값: google/gemini-3-flash-preview",
            "settings.hotkey_label":       "OCR 캡처 단축키:",
            "settings.hotkey_hint":        "최소 하나의 수정자 키를 포함해야 합니다 (⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command)",
            "settings.press_shortcut":     "단축키를 입력하세요...",
            "settings.language_label":     "언어:",
            "alert.screen_capture_title":   "스크린 캡처 불가",
            "alert.screen_capture_message": "시스템 설정 → 개인정보보호 및 보안 → 화면 녹화에서 이 앱을 허용하세요.",
            "alert.open_settings":          "시스템 설정 열기",
            "alert.cancel":                 "취소",
            "error.image_conversion": "이미지 변환 실패",
            "error.invalid_response": "잘못된 API 응답",
            "error.no_content":       "API 응답에 콘텐츠 없음",
        ],
        "es": [
            "menu.ocr_capture":     "Captura OCR (%@)",
            "menu.processing":      "Reconociendo...",
            "menu.settings":        "Preferencias...",
            "menu.quit":            "Salir",
            "status.set_api_key":   "Por favor, establece la clave API primero",
            "status.processing":    "Reconociendo...",
            "status.copied":        "Copiado al portapapeles",
            "status.no_text":       "No se detectó texto",
            "status.error":         "Error: %@",
            "toast.capture_success": "Captura de pantalla realizada, reconociendo...",
            "toast.ocr_complete":    "OCR completado, copiado al portapapeles",
            "toast.no_text":         "No se detectó texto",
            "toast.ocr_failed":      "Error en el reconocimiento",
            "settings.api_section":        "Configuración de API",
            "settings.hotkey_section":     "Atajo de teclado",
            "settings.language_section":   "Idioma",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "Model ID",
            "settings.model_hint":         "Predeterminado: google/gemini-3-flash-preview",
            "settings.hotkey_label":       "Atajo para Captura OCR:",
            "settings.hotkey_hint":        "Debe incluir al menos una tecla modificadora (⌃ Control / ⌥ Opción / ⇧ Mayús / ⌘ Comando)",
            "settings.press_shortcut":     "Presiona las teclas de atajo...",
            "settings.language_label":     "Idioma:",
            "alert.screen_capture_title":   "No se puede capturar la pantalla",
            "alert.screen_capture_message": "Por favor, permite esta aplicación en Preferencias del Sistema → Privacidad y Seguridad → Grabación de pantalla.",
            "alert.open_settings":          "Abrir Preferencias del Sistema",
            "alert.cancel":                 "Cancelar",
            "error.image_conversion": "Error en la conversión de imagen",
            "error.invalid_response": "Respuesta inválida de la API",
            "error.no_content":       "Sin contenido en la respuesta de la API",
        ],
        "fr": [
            "menu.ocr_capture":     "Capture OCR (%@)",
            "menu.processing":      "Reconnaissance en cours...",
            "menu.settings":        "Paramètres...",
            "menu.quit":            "Quitter",
            "status.set_api_key":   "Veuillez d'abord configurer la clé API",
            "status.processing":    "Reconnaissance en cours...",
            "status.copied":        "Copié dans le presse-papiers",
            "status.no_text":       "Aucun texte détecté",
            "status.error":         "Erreur : %@",
            "toast.capture_success": "Capture d'écran réalisée, reconnaissance en cours...",
            "toast.ocr_complete":    "OCR terminé, copié dans le presse-papiers",
            "toast.no_text":         "Aucun texte détecté",
            "toast.ocr_failed":      "Échec de la reconnaissance",
            "settings.api_section":        "Paramètres API",
            "settings.hotkey_section":     "Raccourci clavier",
            "settings.language_section":   "Langue",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "Model ID",
            "settings.model_hint":         "Par défaut : google/gemini-3-flash-preview",
            "settings.hotkey_label":       "Raccourci OCR Capture :",
            "settings.hotkey_hint":        "Doit inclure au moins une touche de modification (⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command)",
            "settings.press_shortcut":     "Appuyez sur les touches de raccourci...",
            "settings.language_label":     "Langue :",
            "alert.screen_capture_title":   "Impossible de capturer l'écran",
            "alert.screen_capture_message": "Veuillez autoriser cette app dans Paramètres système → Confidentialité et sécurité → Enregistrement de l'écran.",
            "alert.open_settings":          "Ouvrir les paramètres système",
            "alert.cancel":                 "Annuler",
            "error.image_conversion": "Échec de la conversion d'image",
            "error.invalid_response": "Réponse API invalide",
            "error.no_content":       "Aucun contenu dans la réponse API",
        ],
        "de": [
            "menu.ocr_capture":     "OCR-Erfassung (%@)",
            "menu.processing":      "Wird erkannt...",
            "menu.settings":        "Einstellungen...",
            "menu.quit":            "Beenden",
            "status.set_api_key":   "Bitte stellen Sie zuerst den API-Schlüssel ein",
            "status.processing":    "Wird erkannt...",
            "status.copied":        "In die Zwischenablage kopiert",
            "status.no_text":       "Kein Text erkannt",
            "status.error":         "Fehler: %@",
            "toast.capture_success": "Screenshot erfasst, wird erkannt...",
            "toast.ocr_complete":    "OCR abgeschlossen, in die Zwischenablage kopiert",
            "toast.no_text":         "Kein Text erkannt",
            "toast.ocr_failed":      "Erkennung fehlgeschlagen",
            "settings.api_section":        "API-Einstellungen",
            "settings.hotkey_section":     "Tastenkürzel",
            "settings.language_section":   "Sprache",
            "settings.api_key":            "OpenRouter API Key",
            "settings.model_id":           "Model ID",
            "settings.model_hint":         "Standard: google/gemini-3-flash-preview",
            "settings.hotkey_label":       "OCR-Erfassungs-Tastenkürzel:",
            "settings.hotkey_hint":        "Muss mindestens eine Modifiertaste enthalten (⌃ Strg / ⌥ Alt / ⇧ Umschalt / ⌘ Befehl)",
            "settings.press_shortcut":     "Tastenkürzel drücken...",
            "settings.language_label":     "Sprache:",
            "alert.screen_capture_title":   "Bildschirm kann nicht erfasst werden",
            "alert.screen_capture_message": "Bitte erlauben Sie diese App in Systemeinstellungen → Datenschutz & Sicherheit → Bildschirmaufnahme.",
            "alert.open_settings":          "Systemeinstellungen öffnen",
            "alert.cancel":                 "Abbrechen",
            "error.image_conversion": "Bildkonvertierung fehlgeschlagen",
            "error.invalid_response": "Ungültige API-Antwort",
            "error.no_content":       "Kein Inhalt in der API-Antwort",
        ],
    ]
}
