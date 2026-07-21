import AppKit
import SwiftUI

@main
struct NetworkTrafficLightApp: App {
    @StateObject private var model: NetworkStatusViewModel
    @StateObject private var statusItemController: StatusItemController

    init() {
        let model = NetworkStatusViewModel()
        _model = StateObject(wrappedValue: model)
        _statusItemController = StateObject(
            wrappedValue: StatusItemController(model: model)
        )
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
