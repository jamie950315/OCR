import SwiftUI
import Carbon

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lm: LocalizationManager
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("modelId") private var modelId = "google/gemini-2.5-pro-preview"
    @State private var isRecordingHotkey = false
    @State private var hotkeyDisplay = ""
    @State private var monitor: Any?

    var body: some View {
        Form {
            Section(lm.t("settings.api_section")) {
                SecureField(lm.t("settings.api_key"), text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField(lm.t("settings.model_id"), text: $modelId)
                    .textFieldStyle(.roundedBorder)

                Text(lm.t("settings.model_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(lm.t("settings.hotkey_section")) {
                HStack {
                    Text(lm.t("settings.hotkey_label"))

                    Button(action: toggleRecording) {
                        Text(isRecordingHotkey ? lm.t("settings.press_shortcut") : hotkeyDisplay)
                            .frame(minWidth: 120)
                            .foregroundColor(isRecordingHotkey ? .red : .primary)
                    }
                    .buttonStyle(.bordered)
                }

                Text(lm.t("settings.hotkey_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(lm.t("settings.language_section")) {
                HStack {
                    Text(lm.t("settings.language_label"))
                    Picker("", selection: $lm.language) {
                        ForEach(LocalizationManager.Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 340)
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
