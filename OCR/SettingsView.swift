import SwiftUI
import Carbon

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("modelId") private var modelId = "google/gemini-2.5-pro-preview"
    @State private var isRecordingHotkey = false
    @State private var hotkeyDisplay = ""
    @State private var monitor: Any?

    var body: some View {
        Form {
            Section("API 設定") {
                SecureField("OpenRouter API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("模型 ID", text: $modelId)
                    .textFieldStyle(.roundedBorder)

                Text("預設：google/gemini-2.5-pro-preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("快捷鍵") {
                HStack {
                    Text("OCR 截圖快捷鍵：")

                    Button(action: toggleRecording) {
                        Text(isRecordingHotkey ? "請按下快捷鍵組合..." : hotkeyDisplay)
                            .frame(minWidth: 120)
                            .foregroundColor(isRecordingHotkey ? .red : .primary)
                    }
                    .buttonStyle(.bordered)
                }

                Text("需包含至少一個修飾鍵（⌃ Control / ⌥ Option / ⇧ Shift / ⌘ Command）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 280)
        .onAppear {
            hotkeyDisplay = appState.hotkeyDisplayString
        }
        .onDisappear {
            stopRecording()
            appState.apiKey = apiKey
            appState.modelId = modelId
            appState.registerHotkey()
        }
    }

    private func toggleRecording() {
        if isRecordingHotkey {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecordingHotkey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mods.contains(.command) || mods.contains(.control) ||
                  mods.contains(.option) || mods.contains(.shift) else {
                return nil
            }

            let carbonMods = HotkeyManager.carbonModifiers(from: mods)
            let keyCode = UInt32(event.keyCode)

            appState.hotkeyKeyCode = keyCode
            appState.hotkeyModifiers = carbonMods
            hotkeyDisplay = HotkeyManager.displayString(keyCode: keyCode, modifiers: carbonMods)

            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecordingHotkey = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
