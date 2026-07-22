import AppKit
import NetworkTrafficLightCore
import SwiftUI

@main
struct NetworkTrafficLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private lazy var reopenCoordinator = AppReopenCoordinator { [weak self] in
        self?.statusItemController?.showPopover()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItemIfNeeded()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        configureStatusItemIfNeeded()
        reopenCoordinator.handleReopen()
        return true
    }

    private func configureStatusItemIfNeeded() {
        guard statusItemController == nil else {
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(model: NetworkStatusViewModel())
    }
}
