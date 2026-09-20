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
    @StateObject private var configurationTest = ConfigurationTestController()

    var body: some View {
        Form {
            Section(lm.t("settings.api_section")) {
                SecureField(lm.t("settings.api_key"), text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField(lm.t("settings.model_id"), text: $modelId)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        if configurationTest.isTesting { configurationTest.invalidate() }
                        else {
                            configurationTest.start(apiKey: apiKey, model: modelId,
                                reasoning: ReasoningEffort(rawValue: reasoningEffort) ?? .low)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if configurationTest.isTesting { ProgressView().controlSize(.mini) }
                            Text(configurationTest.isTesting ? "Cancel" : "Test")
                        }
                    }
                    .disabled(!configurationTest.isTesting && (apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isBenchmarkRunning || appState.isCaptureActive))
                    .help("Send one short prompt with this API key, model, and reasoning effort. Provider charges may apply.")
                }

                if let message = configurationTest.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(configurationTest.isTesting ? Color.secondary : configurationTest.succeeded ? Color.green : Color.red)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(lm.t("settings.model_hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Test checks a short text reply, not vision/OCR accuracy or the provider's internal reasoning strength.")
                    .font(.caption).foregroundStyle(.secondary)

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
                .disabled(appState.isCaptureActive || configurationTest.isTesting)

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
            configurationTest.invalidate()
            stopRecording()
            appState.apiKey = apiKey
            appState.modelId = modelId
            appState.registerHotkey()
        }
        .onChange(of: apiKey) { configurationTest.invalidate() }
        .onChange(of: modelId) { configurationTest.invalidate() }
        .onChange(of: reasoningEffort) { configurationTest.invalidate() }
        .onChange(of: appState.isBenchmarkRunning) { if appState.isBenchmarkRunning { configurationTest.invalidate() } }
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
