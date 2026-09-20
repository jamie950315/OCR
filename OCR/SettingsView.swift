import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lm: LocalizationManager
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("modelId") private var modelId = AppState.defaultModelId
    @AppStorage("reasoningEffort") private var reasoningEffort = "low"
    @State private var isRecordingHotkey = false
    @State private var hotkeyDisplay = ""
    @State private var monitor: Any?
    @State private var launchAtLogin = false
    @State private var hideDockIcon = true

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

                Picker("Reasoning effort", selection: $reasoningEffort) {
                    ForEach(ReasoningEffort.allCases) { effort in
                        Text(effort.displayName).tag(effort.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text("Available efforts depend on the model. Gemini 3.5 Flash Lite does not support Off. Low is the app default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Model Benchmark") {
                Button("Run Benchmark…") {
                    BenchmarkWindowController.shared.show(
                        model: modelId,
                        reasoning: ReasoningEffort(rawValue: reasoningEffort) ?? .low
                    )
                }
                .disabled(appState.isCaptureActive)

                Text("Compare models using 50 built-in OCR problems. A separate window shows live responses and progress. API charges apply only when you start a run.")
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

            Section(lm.t("settings.general_section")) {
                Toggle(lm.t("settings.launch_at_login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) {
                        do {
                            if launchAtLogin {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }

                Toggle(lm.t("settings.hide_dock_icon"), isOn: $hideDockIcon)
                    .onChange(of: hideDockIcon) {
                        appState.hideDockIcon = hideDockIcon
                    }
            }

            Section(lm.t("settings.language_section")) {
                Picker(lm.t("settings.language_label"), selection: Binding(
                    get: { lm.language },
                    set: { lm.setLanguage($0) }
                )) {
                    ForEach(LocalizationManager.Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 650)
        .onAppear {
            hotkeyDisplay = appState.hotkeyDisplayString
            launchAtLogin = SMAppService.mainApp.status == .enabled
            hideDockIcon = appState.hideDockIcon
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
