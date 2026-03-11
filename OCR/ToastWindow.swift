import Cocoa
import SwiftUI

class ToastWindow {
    private var window: NSPanel?
    private var dismissTimer: Timer?

    static let shared = ToastWindow()

    func show(icon: String, message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [self] in
            dismiss()

            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            panel.isMovableByWindowBackground = false
            panel.hidesOnDeactivate = false

            let hostingView = NSHostingView(rootView: ToastView(icon: icon, message: message))
            hostingView.frame = NSRect(x: 0, y: 0, width: 260, height: 56)
            panel.contentView = hostingView
            panel.setContentSize(hostingView.fittingSize)

            // Position at top-center of the main screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let panelSize = panel.frame.size
                let x = screenFrame.midX - panelSize.width / 2
                let y = screenFrame.maxY - panelSize.height - 20
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 1
            }

            self.window = panel

            dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.window = nil
        })
    }
}

private struct ToastView: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
