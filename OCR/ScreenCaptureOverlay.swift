import Cocoa
import ScreenCaptureKit

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class ScreenCaptureOverlay {
    var onComplete: ((CGImage?) -> Void)?
    private var windows: [NSWindow] = []
    private var escapeMonitor: Any?

    func show() {
        NSCursor.crosshair.push()

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancel()
                return nil
            }
            return event
        }

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .init(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onSelected = { [weak self] rect in
                self?.captureRegion(rect, on: screen)
            }
            view.onCancelled = { [weak self] in
                self?.cancel()
            }

            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func captureRegion(_ viewRect: CGRect, on screen: NSScreen) {
        cleanup()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            let captureRect = convertToCGCoordinates(viewRect, on: screen)

            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    guard let display = content.displays.first(where: { display in
                        let displayRect = CGRect(
                            x: CGFloat(display.frame.origin.x),
                            y: CGFloat(display.frame.origin.y),
                            width: CGFloat(display.width),
                            height: CGFloat(display.height)
                        )
                        return displayRect.contains(CGPoint(x: captureRect.midX, y: captureRect.midY))
                    }) ?? content.displays.first else {
                        await MainActor.run { onComplete?(nil) }
                        return
                    }

                    let scaleFactor = screen.backingScaleFactor

                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    let config = SCStreamConfiguration()
                    config.sourceRect = captureRect
                    config.width = Int(captureRect.width * scaleFactor)
                    config.height = Int(captureRect.height * scaleFactor)
                    config.showsCursor = false

                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: config
                    )
                    await MainActor.run { onComplete?(image) }
                } catch {
                    await MainActor.run {
                        showScreenRecordingAlert()
                        onComplete?(nil)
                    }
                }
            }
        }
    }

    private func cancel() {
        cleanup()
        onComplete?(nil)
    }

    private func cleanup() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        NSCursor.pop()

        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    private func convertToCGCoordinates(_ viewRect: CGRect, on screen: NSScreen) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else { return viewRect }
        let primaryHeight = primaryScreen.frame.height

        let screenX = screen.frame.origin.x + viewRect.origin.x
        let screenY = screen.frame.origin.y + viewRect.origin.y

        return CGRect(
            x: screenX,
            y: primaryHeight - screenY - viewRect.height,
            width: viewRect.width,
            height: viewRect.height
        )
    }

    private func showScreenRecordingAlert() {
        let lm = LocalizationManager.shared
        let alert = NSAlert()
        alert.messageText = lm.t("alert.screen_capture_title")
        alert.informativeText = lm.t("alert.screen_capture_message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: lm.t("alert.open_settings"))
        alert.addButton(withTitle: lm.t("alert.cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Selection View

class SelectionView: NSView {
    var onSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var startPoint: NSPoint?
    private var selectionRect: CGRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds)
        if selectionRect.width > 1 && selectionRect.height > 1 {
            path.appendRect(selectionRect)
            path.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.3).setFill()
        path.fill()

        if selectionRect.width > 1 && selectionRect.height > 1 {
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: selectionRect)
            borderPath.lineWidth = 1.5
            borderPath.stroke()

            let sizeText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            ]
            let textSize = (sizeText as NSString).size(withAttributes: attrs)
            let bgRect = CGRect(
                x: selectionRect.midX - textSize.width / 2 - 6,
                y: selectionRect.maxY + 4,
                width: textSize.width + 12,
                height: textSize.height + 4
            )
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()

            let textPoint = NSPoint(
                x: selectionRect.midX - textSize.width / 2,
                y: selectionRect.maxY + 6
            )
            (sizeText as NSString).draw(at: textPoint, withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if selectionRect.width > 5 && selectionRect.height > 5 {
            onSelected?(selectionRect)
        } else {
            onCancelled?()
        }
        startPoint = nil
        selectionRect = .zero
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancelled?()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
