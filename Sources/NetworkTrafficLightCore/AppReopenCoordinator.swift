public final class AppReopenCoordinator {
    private let showPopover: () -> Void

    public init(showPopover: @escaping () -> Void) {
        self.showPopover = showPopover
    }

    public func handleReopen() {
        showPopover()
    }
}
