import AppKit
import SwiftUI
import ScreenCaptureKit
import LiltCore
import KeyboardShortcuts

@main
enum LiltApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var libraryWindow: NSWindow!
    private var readerWindow: NSPanel?
    private var captureControls: CaptureControlsPanel?
    private var readerIsCapture = false
    private var readerReadingID: UUID?
    private var nextCaptureFrame: NSRect?
    private var recognitionTask: Task<Void, Never>?
    private var hiddenCaptureWindows: [NSWindow] = []
    private var captureKeyWindow: NSWindow?
    private let selection = ScreenSelection()
    private let shortcut = GlobalShortcut()
    private let permissionGuide = ScreenPermissionGuide()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { model = try AppModel() }
        catch { showFatal(error); return }
        AppUpdates.shared.start()
        makeMenu()
        makeLibrary()
        model.visibilityChanged = { [weak self] in self?.updateVisibility() }
        updateVisibility()
        model.capture = { [weak self] in self?.capture() }
        model.showReader = { [weak self] in self?.showReader() }
        model.openScreenPermissions = { [weak self] in self?.permissionGuide.open() }
        selection.onSelect = { [weak self] capture in self?.recognize(capture) }
        selection.onCancel = { [weak self] in
            self?.model.isCapturing = false
            self?.restoreCaptureWindows()
        }
        shortcut.onClipboard = { [weak self] in self?.readClipboard() }
        shortcut.onPress = { [weak self] in self?.capture() }
        shortcut.register()
        if let error = GlobalShortcut.registrationError() { model.error = error }
        showLibrary()
    }

    func applicationWillTerminate(_ notification: Notification) { permissionGuide.dismiss(); model?.shutdown(); shortcut.unregister() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showLibrary(); return true }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === readerWindow {
            recognitionTask?.cancel()
            model.isCapturing = false
            model.closeReader()
            captureControls?.hide()
        }
    }

    private func updateVisibility() {
        statusItem.isVisible = model.showInMenuBar
        NSApp.setActivationPolicy(model.showInDock ? .regular : .accessory)
    }

    private func restoreCaptureWindows() {
        hiddenCaptureWindows.forEach { $0.orderFront(nil) }
        captureKeyWindow?.makeKey()
        hiddenCaptureWindows.removeAll()
        captureKeyWindow = nil
    }

    private func makeMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Capture & Read", action: #selector(capture), keyEquivalent: "").setShortcut(for: .captureText)
        menu.addItem(withTitle: "Read Clipboard", action: #selector(readClipboard), keyEquivalent: "").setShortcut(for: .readClipboard)
        menu.addItem(.separator())
        menu.addItem(withTitle: "History & Settings…", action: #selector(showLibrary), keyEquivalent: "")
        menu.addItem(withTitle: "Show Reader", action: #selector(showReader), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(AppIdentity.name)", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem = NSStatusBar.system.statusItem(withLength: AppIdentity.isDevelopment ? NSStatusItem.variableLength : NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: AppIdentity.name)
        if AppIdentity.isDevelopment { statusItem.button?.title = " Dev" }
        statusItem.button?.toolTip = "\(AppIdentity.name) · Capture & Read"
        statusItem.menu = menu

        let main = NSMenu()
        let appMenu = NSMenu()
        let about = appMenu.addItem(withTitle: "About \(AppIdentity.name)", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        if AppUpdates.shared.isAvailable {
            let update = appMenu.addItem(withTitle: "Check for Updates…", action: #selector(AppUpdates.checkForUpdates(_:)), keyEquivalent: "")
            update.target = AppUpdates.shared
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(AppIdentity.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let app = NSMenuItem(); app.submenu = appMenu; main.addItem(app)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"),
                                     ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"),
                                     ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        edit.submenu = editMenu; main.addItem(edit)
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        let historyItem = windowMenu.addItem(withTitle: "History & Settings", action: #selector(showLibrary), keyEquivalent: "0")
        historyItem.target = self
        let readerItem = windowMenu.addItem(withTitle: "Show Reader", action: #selector(showReader), keyEquivalent: "1")
        readerItem.target = self
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu; main.addItem(windowItem)
        NSApp.mainMenu = main
    }

    private func makeLibrary() {
        libraryWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 950, height: 640),
                                 styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                 backing: .buffered, defer: false)
        libraryWindow.title = AppIdentity.name
        libraryWindow.titlebarAppearsTransparent = true
        libraryWindow.isReleasedWhenClosed = false
        libraryWindow.contentView = NSHostingView(rootView: LibraryView(model: model))
        libraryWindow.setFrameAutosaveName("LiltLibrary")
        libraryWindow.center()
    }

    @objc private func showLibrary() {
        libraryWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        showLibrary()
        NotificationCenter.default.post(name: .showLiltAbout, object: nil)
    }

    @objc private func showReader() {
        let isCapture = model.captureImage != nil
        let changedReading = readerReadingID != model.current?.id
        if readerWindow != nil, readerIsCapture != isCapture {
            captureControls = nil
            readerWindow?.delegate = nil
            readerWindow?.close()
            readerWindow = nil
        }
        if readerWindow == nil {
            let styles: NSWindow.StyleMask = isCapture ? [.borderless] : [.titled, .closable, .resizable, .fullSizeContentView]
            let panel = ReaderPanel(contentRect: NSRect(x: 0, y: 0, width: 690, height: 520),
                                    styleMask: styles, backing: .buffered, defer: false)
            panel.title = "\(AppIdentity.name) Reader"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            if isCapture {
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.isMovableByWindowBackground = true
                panel.contentMinSize = NSSize(width: 1, height: 1)
                panel.contentView = NSHostingView(rootView: CaptureReaderView(model: model, playback: model.playback,
                    close: { [weak panel] in panel?.close() }))
                captureControls = CaptureControlsPanel(reader: panel, model: model)
                panel.onTab = { [weak self] in self?.captureControls?.showForKeyboard() }
                panel.onSpace = { [weak model] in model?.togglePlayback() }
            } else {
                panel.contentView = NSHostingView(rootView: ReaderView(model: model, playback: model.playback,
                    openHistory: { [weak self] in self?.showLibrary() }))
            }
            panel.center()
            readerWindow = panel
        }
        if isCapture {
            if let frame = nextCaptureFrame {
                readerWindow?.setFrame(frame, display: true)
                nextCaptureFrame = nil
            } else if changedReading, let size = model.captureImage?.size, let screen = NSScreen.main {
                let visible = screen.visibleFrame
                let capture = NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                                     width: size.width, height: size.height)
                readerWindow?.setFrame(CaptureLayout.windowFrame(around: capture, visibleFrame: visible), display: true)
            }
        }
        readerIsCapture = isCapture
        readerReadingID = model.current?.id
        readerWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func readClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            model.error = "Copy some text first, then choose Read Clipboard."
            showLibrary()
            return
        }
        model.read(text, source: "Clipboard")
    }

    @objc private func capture() {
        guard !model.isCapturing else { return }
        model.closeReader()
        captureControls?.hide()
        captureKeyWindow = NSApp.keyWindow
        hiddenCaptureWindows = NSApp.windows.filter { $0.isVisible }
        hiddenCaptureWindows.forEach { $0.orderOut(nil) }
        model.isCapturing = true
        model.needsScreenPermission = false
        Task {
            do {
                try await Task.sleep(for: .milliseconds(120))
                try await selection.begin()
            }
            catch {
                restoreCaptureWindows()
                model.isCapturing = false
                model.needsScreenPermission = (error as NSError).domain == SCStreamErrorDomain && (error as NSError).code == SCStreamError.userDeclined.rawValue
                model.error = model.needsScreenPermission ? AppIdentity.capturePermissionMessage : error.localizedDescription
                showLibrary()
            }
        }
    }

    private func recognize(_ capture: SelectedCapture) {
        hiddenCaptureWindows.removeAll()
        captureKeyWindow = nil
        nextCaptureFrame = CaptureLayout.windowFrame(around: capture.frame, visibleFrame: capture.screen.visibleFrame)
        model.previewCapture(capture.image, pointSize: capture.frame.size)
        recognitionTask = Task {
            do {
                let local = try await TextRecognition.recognize(capture.image)
                let recognized = try await model.filterCapture(local, image: capture.image)
                try Task.checkCancellation()
                guard model.current == nil else { model.isCapturing = false; return }
                try model.readCapture(recognized, image: capture.image, pointSize: capture.frame.size)
                readerReadingID = model.current?.id
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                model.error = (error as? URLError)?.code == .timedOut
                    ? "The AI provider took too long (30 seconds without data, or 60 seconds total). Try a smaller capture or another model. Turn off AI filtering to use local Vision OCR."
                    : error.localizedDescription
                model.status = "Couldn’t read this capture"
            }
            model.isCapturing = false
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func showFatal(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
        NSApp.terminate(nil)
    }
}

private final class ReaderPanel: NSPanel {
    var onTab: (() -> Void)?
    var onSpace: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48, let onTab { onTab() }
        else if event.keyCode == 49, let onSpace { onSpace() }
        else { super.keyDown(with: event) }
    }
    override var canBecomeKey: Bool { true }
    override func performClose(_ sender: Any?) { close() }
}
