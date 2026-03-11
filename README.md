# OCR — macOS Menu Bar OCR Tool

A lightweight macOS menu bar application that captures screen regions and performs OCR using OpenRouter API (Gemini model). Recognized text is automatically copied to your clipboard.

## Features

- **Menu Bar App** — Lives in the menu bar, no dock icon
- **Region Selection** — Click and drag to select any area on screen
- **Global Hotkey** — Default ⌃⌥O (Control+Option+O), fully customizable
- **Instant Clipboard** — OCR results are automatically copied
- **Toast Notifications** — Visual feedback for capture, completion, and errors
- **Multi-Display** — Works across all connected screens
- **8 Languages** — English, 繁體中文, 简体中文, 日本語, 한국어, Español, Français, Deutsch

## Requirements

- macOS 26.2+
- Xcode 26+
- [OpenRouter](https://openrouter.ai/) API key
- Screen Recording permission (prompted on first capture)

## Setup

1. Open `OCR.xcodeproj` in Xcode
2. Build and run (⌘R)
3. The app icon appears in the menu bar
4. On first launch, the Settings window opens — enter your OpenRouter API key
5. Press ⌃⌥O to start capturing

## Usage

1. Press the global hotkey (default: **⌃⌥O**)
2. Screen dims — click and drag to select the region containing text
3. Release to capture — a toast confirms the capture
4. Wait for OCR processing — another toast confirms when text is copied
5. Paste (⌘V) anywhere

Press **Escape** to cancel a capture.

## Settings

Access via menu bar icon → Settings... (or ⌘,)

| Setting | Description | Default |
|---------|-------------|---------|
| API Key | Your OpenRouter API key | — |
| Model ID | OpenRouter model identifier | `google/gemini-3-flash-preview` |
| Hotkey | Global keyboard shortcut | ⌃⌥O |
| Language | UI language | 繁體中文 |

## Permissions

- **Screen Recording** — Required for screen capture. macOS will prompt on first use. Grant access in System Settings → Privacy & Security → Screen Recording.
- **Network** — Enabled via App Sandbox entitlement for OpenRouter API calls.

## License

MIT
