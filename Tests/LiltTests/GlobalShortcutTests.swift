import XCTest
import Carbon
import KeyboardShortcuts
@testable import Lilt

final class GlobalShortcutTests: XCTestCase {
    @MainActor func testDuplicateActionIsRejectedAndCurrentShortcutIsAllowed() throws {
        let capture = try XCTUnwrap(KeyboardShortcuts.Name.captureText.shortcut)
        let clipboard = try XCTUnwrap(KeyboardShortcuts.Name.readClipboard.shortcut)
        guard case .disallow(let reason) = GlobalShortcut.validate(clipboard, for: .captureText) else {
            return XCTFail("The two actions must not share a shortcut")
        }
        XCTAssertTrue(reason.contains("Read clipboard"))
        guard case .allow = GlobalShortcut.validate(capture, for: .captureText) else {
            return XCTFail("Re-recording the current shortcut should be allowed")
        }
    }

    @MainActor func testExistingCarbonRegistrationIsRejectedAndProbeIsReleased() throws {
        let candidate = KeyboardShortcuts.Shortcut(.f19, modifiers: [.command, .control, .option, .shift])
        var reservation: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(candidate.carbonKeyCode), UInt32(candidate.carbonModifiers),
            EventHotKeyID(signature: 0x54455354, id: 1), GetApplicationEventTarget(), 0, &reservation)
        guard status == noErr else { throw XCTSkip("Test shortcut is already reserved") }
        defer { if let reservation { UnregisterEventHotKey(reservation) } }
        guard case .disallow = GlobalShortcut.validate(candidate, for: .captureText) else {
            return XCTFail("An existing app registration must be detected")
        }
        if let handle = reservation { UnregisterEventHotKey(handle); reservation = nil }
        for _ in 0..<2 {
            guard case .allow = GlobalShortcut.validate(candidate, for: .captureText) else {
                return XCTFail("Validation must release its temporary registration")
            }
        }
    }
}
