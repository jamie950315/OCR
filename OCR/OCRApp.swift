import SwiftUI

@main
struct OCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "text.viewfinder")
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
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
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if appState.isProcessing {
            Label("正在辨識中...", systemImage: "hourglass")
        }

        if let message = appState.statusMessage {
            Text(message)
        }

        Button("OCR 截圖 (\(appState.hotkeyDisplayString))") {
            appState.startCapture()
        }
        .disabled(appState.isProcessing)

        Divider()

        SettingsLink {
            Text("設定...")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("結束") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .onChange(of: appState.shouldOpenSettings) {
            if appState.shouldOpenSettings {
                appState.shouldOpenSettings = false
                openSettings()
            }
        }
    }
}
