import AppKit
import Combine
import Sparkle

@MainActor
final class AppUpdates: NSObject, ObservableObject, NSMenuItemValidation {
    static let shared = AppUpdates()
    @Published private(set) var canCheck = false
    @Published var automaticChecks = false {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticChecks }
    }
    private var controller: SPUStandardUpdaterController?
    private var observation: NSKeyValueObservation?

    var isAvailable: Bool { !AppIdentity.isDevelopment && Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil }

    func start() {
        guard isAvailable, controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        automaticChecks = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor in self?.canCheck = updater.canCheckForUpdates }
        }
    }

    @objc func checkForUpdates(_ sender: Any? = nil) {
        controller?.checkForUpdates(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { canCheck }
}
