// WindowChrome.swift — standard macOS window behaviour for the main window.
//
// The app hides its title bar (`.windowStyle(.hiddenTitleBar)`), which strips
// the usual drag + double-click-to-zoom affordances. This file re-installs the
// things users expect of any macOS window:
//
//   • drag the window by its empty top bar;
//   • double-click the top bar to zoom/restore — toggling between a "typical"
//     (maximised) size and the previous size, exactly like the standard
//     title-bar double-click (delegated to AppKit's native `zoom(_:)`);
//   • remember the window's last size & position, and survive a *corrupt* or
//     *off-screen* saved frame by falling back to a sensible centred default.
//
// The green traffic-light button already does its native full-screen on its own;
// this file only needs to cover the title-bar gestures the hidden bar lost.

import SwiftUI
#if os(macOS)
import AppKit

// MARK: - Frame coordinator

/// Owns the main window's frame: persistence + launch validation, and the
/// zoom/restore toggle. Installed once, from the top-bar drag handle, and safe
/// to call repeatedly (it guards against re-attaching to the same window).
final class WindowFrameCoordinator {
    static let shared = WindowFrameCoordinator()

    /// UserDefaults keys for the persisted frame (stored as four doubles so the
    /// value is trivially readable/validatable, unlike an archived NSRect).
    private let frameKeyPrefix = "DaiJishowMainWindowFrame"
    /// The "typical" size the window falls back to when nothing sensible is saved.
    private let defaultSize = CGSize(width: 1320, height: 880)
    /// Smallest frame we will ever accept from a saved value; below this a save
    /// is treated as corrupt and reset. Matches DaiJishowMacApp's minimum window frame.
    private let minSize = CGSize(width: 820, height: 560)

    private var window: NSWindow?
    private var observers: [NSObjectProtocol] = []

    /// Configure the window, restore a saved (validated) frame, and start
    /// persisting. Idempotent — safe to call on every onAppear / move-to-window.
    func attach(to window: NSWindow) {
        guard self.window != window else { return }
        self.window = window

        // We manage the frame ourselves, so disable AppKit's own state
        // restoration to avoid two mechanisms fighting over the saved frame.
        window.isRestorable = false
        // Guarantee the window is resizable so zoom / the green button have
        // somewhere to go; keep it hidden-title-bar (transparent + full-height).
        window.styleMask.insert(.resizable)

        restoreFrame()
        registerObservers(on: window)
    }

    // MARK: Zoom / restore

    /// Toggle the zoom — the macOS double-click-title-bar behaviour. AppKit's
    /// `zoom(_:)` expands to the maximised "standard" frame, or (if already
    /// zoomed) collapses back to the size the window had before it was zoomed.
    func toggleZoom() {
        guard let window else { return }
        window.zoom(nil)
    }

    // MARK: Observation

    private func registerObservers(on window: NSWindow) {
        // Persist position/size on every user-driven change so a relaunch
        // restores exactly where the user left the window. A live (user-dragged)
        // resize ends with didEndLiveResize; we also catch didMove (repositioning)
        // and save on close as a final flush.
        let endResize = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main
        ) { [weak self] _ in self?.saveFrame() }

        let moved = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: window, queue: .main
        ) { [weak self] _ in self?.saveFrame() }

        let closing = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in self?.teardown() }

        observers = [endResize, moved, closing]
    }

    private func teardown() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        saveFrame()
        window = nil
    }

    // MARK: Persist / restore

    private func saveFrame() {
        guard let frame = window?.frame else { return }
        let d = UserDefaults.standard
        d.set(frame.origin.x, forKey: frameKeyPrefix + ".x")
        d.set(frame.origin.y, forKey: frameKeyPrefix + ".y")
        d.set(frame.size.width, forKey: frameKeyPrefix + ".w")
        d.set(frame.size.height, forKey: frameKeyPrefix + ".h")
    }

    private func readSavedFrame() -> NSRect? {
        let d = UserDefaults.standard
        guard d.object(forKey: frameKeyPrefix + ".w") != nil,
              d.object(forKey: frameKeyPrefix + ".h") != nil else { return nil }
        return NSRect(
            x: d.double(forKey: frameKeyPrefix + ".x"),
            y: d.double(forKey: frameKeyPrefix + ".y"),
            width: d.double(forKey: frameKeyPrefix + ".w"),
            height: d.double(forKey: frameKeyPrefix + ".h")
        )
    }

    private func restoreFrame() {
        guard let window else { return }
        if let saved = readSavedFrame(), isValid(saved) {
            window.setFrame(saved, display: true, animate: false)
        } else {
            // Corrupt / off-screen / first run: fall back to a sane, centred
            // default so the UX is never launched crunched or off-screen.
            let target = defaultFrame(on: window.screen ?? NSScreen.main)
            window.setFrame(target, display: true, animate: false)
            saveFrame()
        }
    }

    /// A saved frame is trustworthy only if it is large enough *and* intersects a
    /// visible screen (rejects stale saves from a disconnected monitor).
    private func isValid(_ frame: NSRect) -> Bool {
        guard frame.width >= minSize.width, frame.height >= minSize.height else { return false }
        // Allow a generous margin so a window parked mostly on a (now-missing)
        // secondary screen that has since gone is still recovered.
        let probe = frame.insetBy(dx: -200, dy: -200)
        return NSScreen.screens.contains { $0.visibleFrame.intersects(probe) }
    }

    private func defaultFrame(on screen: NSScreen?) -> NSRect {
        let vf = (screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // Keep the frame on-screen even on small displays.
        let w = min(defaultSize.width, vf.width)
        let h = min(defaultSize.height, vf.height)
        return NSRect(
            x: (vf.width - w) / 2 + vf.minX,
            y: (vf.height - h) / 2 + vf.minY,
            width: w,
            height: h
        )
    }
}

/// Zero-hit-test accessor that attaches `WindowFrameCoordinator` to the
/// enclosing `NSWindow` without intercepting clicks or drags (the native
/// unified macOS toolbar handles title-bar drag & double-click-to-zoom).
struct WindowFrameAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> FrameAccessorView {
        FrameAccessorView()
    }
    func updateNSView(_ nsView: FrameAccessorView, context: Context) {}
}

final class FrameAccessorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            WindowFrameCoordinator.shared.attach(to: window)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

// MARK: - Top-bar drag + zoom handle

/// A transparent NSView backing the main window's top bar. It lets the user
/// *drag* the window from the otherwise-dead title-bar area, and *double-clicks*
/// it to toggle the zoom/restore. Controls rendered above it (in the top nav bar)
/// still receive their own clicks, since this view only gets events on empty
/// areas of the bar.
struct WindowZoomHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> ZoomHandleView {
        ZoomHandleView()
    }
    func updateNSView(_ nsView: ZoomHandleView, context: Context) {}
}

final class ZoomHandleView: NSView {
    private var dragScreenOrigin: NSPoint?
    private var windowFrameOrigin: NSPoint?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            WindowFrameCoordinator.shared.attach(to: window)
        }
    }

    // Ensure the empty handle is always hit-testable, even with no content.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else { return nil }
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    // Single-click-drag: move the window by hand.
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }

        // A double-click zooms/restores instead of starting a drag.
        if event.clickCount >= 2 {
            WindowFrameCoordinator.shared.toggleZoom()
            return
        }

        dragScreenOrigin = NSEvent.mouseLocation
        windowFrameOrigin = window.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let start = dragScreenOrigin,
              let origin = windowFrameOrigin else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - start.x
        let dy = now.y - start.y
        window.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        dragScreenOrigin = nil
        windowFrameOrigin = nil
    }
}
#endif
