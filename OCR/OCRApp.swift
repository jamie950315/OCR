import SwiftUI

@main
struct OCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var lm = LocalizationManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(appState)
                .environmentObject(lm)
        } label: {
            Image(systemName: "text.viewfinder")
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(lm)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.registerHotkey()

        if AppState.shared.apiKey.isEmpty {
            AppState.shared.shouldOpenSettings = true
        }
    }
}

struct MenuContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lm: LocalizationManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if appState.isProcessing {
            Label(lm.t("menu.processing"), systemImage: "hourglass")
        }

        if let message = appState.statusMessage {
            Text(message)
        }

        Button(lm.t("menu.ocr_capture", appState.hotkeyDisplayString)) {
            appState.startCapture()
        }
        .disabled(appState.isProcessing)

        Divider()

        Button(lm.t("menu.settings")) {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button(lm.t("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .onChange(of: appState.shouldOpenSettings) {
            if appState.shouldOpenSettings {
                appState.shouldOpenSettings = false
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
        }
    }
}
