public enum LaunchAtLoginState: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval

    public var isEnabled: Bool {
        self == .enabled
    }

    public var guidance: String? {
        switch self {
        case .requiresApproval:
            "Enable Network Traffic Light in System Settings → General → Login Items."
        case .notRegistered, .enabled:
            nil
        }
    }
}
