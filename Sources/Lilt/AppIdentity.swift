import Foundation

enum AppIdentity {
    static let isDevelopment = Bundle.main.object(forInfoDictionaryKey: "LiltBuildFlavor") as? String == "development"
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Lilt"
    static let build = Bundle.main.object(forInfoDictionaryKey: "LiltBuildID") as? String ?? "Xcode"
    static let signingIdentity = Bundle.main.object(forInfoDictionaryKey: "LiltSigningIdentity") as? String ?? "Unpackaged build"
    static let path = Bundle.main.bundleURL.path
    static var supportFolder: String { isDevelopment ? "Lilt Dev" : "Lilt" }

    static var capturePermissionMessage: String {
        "Allow \(name) in System Settings → Privacy & Security → Screen & System Audio Recording. If it isn’t listed, drag the app from the guide into the list. macOS may ask you to quit and reopen \(name)."
    }
}
