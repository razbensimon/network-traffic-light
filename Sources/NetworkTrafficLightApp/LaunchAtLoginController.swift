import Combine
import NetworkTrafficLightCore
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var state: LaunchAtLoginState = .notRegistered
    @Published private(set) var message: String?

    init() {
        refresh()
    }

    var isEnabled: Bool {
        state.isEnabled
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            state = .enabled
            message = nil
        case .requiresApproval:
            state = .requiresApproval
            message = state.guidance
        default:
            state = .notRegistered
            message = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            message = "Couldn't update Launch at Login. \(error.localizedDescription)"
        }
    }
}
