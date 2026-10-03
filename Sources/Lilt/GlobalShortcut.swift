import Carbon
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureText = Self("captureText", initial: .init(.l, modifiers: [.command, .shift]))
    static let readClipboard = Self("readClipboard", initial: .init(.l, modifiers: [.command, .option]))
}

@MainActor
final class GlobalShortcut {
    var onPress: (() -> Void)?
    var onClipboard: (() -> Void)?

    func register() {
        KeyboardShortcuts.onKeyUp(for: .captureText) { [weak self] in self?.onPress?() }
        KeyboardShortcuts.onKeyUp(for: .readClipboard) { [weak self] in self?.onClipboard?() }
    }

    func unregister() {
        KeyboardShortcuts.removeAllHandlers()
    }

    static func validate(_ shortcut: KeyboardShortcuts.Shortcut, for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.ValidationResult {
        let other: KeyboardShortcuts.Name = name == .captureText ? .readClipboard : .captureText
        if shortcut == other.shortcut {
            return .disallow(reason: "This shortcut is already used for \(other == .captureText ? "Capture" : "Read clipboard").")
        }
        if shortcut == name.shortcut { return .allow }

        // The recorder suspends Lilt's hotkeys while recording. Probe Carbon for
        // registrations owned by other apps, then immediately release the probe.
        var probe: EventHotKeyRef?
        let result = RegisterEventHotKey(UInt32(shortcut.carbonKeyCode), UInt32(shortcut.carbonModifiers),
            EventHotKeyID(signature: 0x4C494C54, id: 99), GetApplicationEventTarget(), 0, &probe)
        if let probe { UnregisterEventHotKey(probe) }
        guard result == noErr else { return .disallow(reason: "This shortcut is unavailable or already registered by another app. Choose another shortcut.") }
        return .allow
    }

    static func registrationError() -> String? {
        for (name, label) in [(KeyboardShortcuts.Name.captureText, "Capture"), (.readClipboard, "Read clipboard")] {
            if let shortcut = name.shortcut, !KeyboardShortcuts.isEnabled(for: name) {
                return "\(label) shortcut \(shortcut) is unavailable. Choose another shortcut in Settings."
            }
        }
        return nil
    }
}
