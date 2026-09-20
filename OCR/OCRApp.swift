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
            OCRStatusLabel()
                .environmentObject(appState)
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
        AppState.shared.applyDockIconPolicy()
        AppState.shared.registerHotkey()

        if AppState.shared.apiKey.isEmpty {
            AppState.shared.shouldOpenSettings = true
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { AppState.shared.shouldOpenSettings = true }
        sender.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let runner = BenchmarkWindowController.shared.runner
        guard runner.isRunning else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Stop the benchmark and quit?"
        alert.informativeText = "The active request and remaining problems will be cancelled. Unsaved results will be lost. Charges already incurred may still apply."
        alert.addButton(withTitle: "Keep Running")
        alert.addButton(withTitle: "Stop and Quit")
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        runner.cancel()
        return .terminateNow
    }
}

private struct OCRStatusLabel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(systemName: "text.viewfinder")
            .onChange(of: appState.shouldOpenSettings, initial: true) {
                guard appState.shouldOpenSettings else { return }
                appState.shouldOpenSettings = false
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
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
        .disabled(appState.isProcessing || appState.isBenchmarkRunning)

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
    }
}
