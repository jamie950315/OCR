# Obviously Can't Remember (OCR)
### macOS Menu Bar OCR Tool

A lightweight macOS menu bar application that captures screen regions and performs OCR using OpenRouter API (Gemini 3.5 Flash Lite with low reasoning effort by default). Recognized text is automatically copied to your clipboard.

## Features

- **Menu Bar App** — Lives in the menu bar, dock icon optional
- **Region Selection** — Click and drag to select any area on screen
- **Global Hotkey** — Default ⌃⌥O (Control+Option+O), fully customizable
- **Instant Clipboard** — OCR results are automatically copied
- **Markdown Tables** — Tables retain their rows, columns, and empty cells; in-cell line breaks use `<br>`, and merged-cell content stays in the top-left cell. Non-table text keeps its original line breaks.
- **Model Benchmark** — Run 50 bundled OCR problems in a separate window, watch the response stream and progress, save results locally, and compare compatible runs from different models.
- **Toast Notifications** — Visual feedback for capture, completion, and errors
- **Multi-Display** — Works across all connected screens
- **Launch at Login** — Optional auto-start when you log in
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
| Model ID | OpenRouter model identifier | `google/gemini-3.5-flash-lite` |
| Reasoning Effort | Model default, off, minimal, low, medium, or high; support depends on the model | Low |
| Hotkey | Global keyboard shortcut | ⌃⌥O |
| Launch at Login | Auto-start on login | Off |
| Hide Dock Icon | Hide the app from the Dock | On |
| Language | UI language | English |

On first launch after upgrading, saved previous Qwen3.8 Flash and legacy Gemini defaults migrate to Gemini 3.5 Flash Lite once. Other custom model IDs are preserved, and you can select a previous model again afterward. Existing reasoning choices are preserved; new installations default to Low.

## Benchmarking Models

Open **Settings → Run Benchmark…**, review the model and reasoning effort, then start the run. The benchmark uploads 50 bundled synthetic images to OpenRouter; provider charges apply. It does not upload your screen captures or read your clipboard. Off is not supported by every model, including Gemini 3.5 Flash Lite.

The window displays progress, the current image, and visible response text as it streams. Cancel stops the active request; requests already processed by a provider may still be billed. A network or API error stops the run rather than repeatedly sending unsupported requests. Screen capture is disabled during a benchmark to avoid overlapping OCR requests.

After a run, inspect the per-problem results and summary, save the run locally, or export/import a JSON file. Saved results include model settings, prompts, responses, scores, and API-reported usage, but never the API key. Results are saved only when requested, under the app's sandboxed Application Support directory.

Comparison requires complete runs with the same dataset, scorer, prompt, and transport version. Different models and reasoning efforts can then be compared fairly. Incomplete or incompatible runs remain inspectable but are not ranked together. Imported results are validated and re-scored before use.

The dataset covers 30 table/mixed-document problems and 20 non-table problems. Exact fidelity is deliberately strict: punctuation, line breaks, indentation, table boundaries, and empty-result compatibility can all affect a pass. These artificial samples are not a general accuracy guarantee. Reported costs are not a billing receipt, and latency varies with provider load.

## Permissions

- **Screen Recording** — Required for screen capture. macOS will prompt on first use. Grant access in System Settings → Privacy & Security → Screen Recording.
- **Network** — Enabled via App Sandbox entitlement for OpenRouter API calls.

## License

MIT
