import Darwin
import Foundation
import SystemConfiguration

public struct InterfaceCandidate: Equatable, Sendable {
    public let name: String
    public let isUp: Bool
    public let isRunning: Bool
    public let isLoopback: Bool
    public let isPointToPoint: Bool

    public init(
        name: String,
        isUp: Bool,
        isRunning: Bool,
        isLoopback: Bool,
        isPointToPoint: Bool
    ) {
        self.name = name
        self.isUp = isUp
        self.isRunning = isRunning
        self.isLoopback = isLoopback
        self.isPointToPoint = isPointToPoint
    }

    public var isEligible: Bool {
        isUp && isRunning && !isLoopback && !isPointToPoint
    }
}

public enum PrimaryInterfaceSelector {
    public static func select(
        configuredName: String?,
        candidates: [InterfaceCandidate]
    ) -> String? {
        if let configuredName,
           candidates.contains(where: { $0.name == configuredName && $0.isEligible }) {
            return configuredName
        }

        return candidates.first(where: \.isEligible)?.name
    }
}

public struct PrimaryInterfaceResolver: Sendable {
    public init() {}

    public func currentInterfaceName() -> String? {
        PrimaryInterfaceSelector.select(
            configuredName: SystemInterfaces.primaryName(),
            candidates: SystemInterfaces.candidates()
        )
    }
}

enum SystemInterfaces {
    static func primaryName() -> String? {
        let key = "State:/Network/Global/IPv4" as CFString
        let values = SCDynamicStoreCopyValue(nil, key) as? [String: Any]
        return values?["PrimaryInterface"] as? String
    }

    static func candidates() -> [InterfaceCandidate] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return []
        }
        defer { freeifaddrs(first) }

        return sequence(first: first, next: { $0.pointee.ifa_next }).compactMap { item in
            guard let rawName = item.pointee.ifa_name else {
                return nil
            }

            let flags = Int32(item.pointee.ifa_flags)
            return InterfaceCandidate(
                name: String(cString: rawName),
                isUp: (flags & IFF_UP) != 0,
                isRunning: (flags & IFF_RUNNING) != 0,
                isLoopback: (flags & IFF_LOOPBACK) != 0,
                isPointToPoint: (flags & IFF_POINTOPOINT) != 0
            )
        }
    }
}
