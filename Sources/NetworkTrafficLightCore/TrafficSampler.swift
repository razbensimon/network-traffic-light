import Darwin
import Foundation

@MainActor
public final class TrafficSampler {
    public var onRate: ((TrafficRate?) -> Void)?

    private let interfaceName: () -> String?
    private let readCounters: (String) -> InterfaceCounters?
    private var timer: Timer?
    private var previous: InterfaceCounters?
    private var smoothed: TrafficRate?

    public init() {
        interfaceName = {
            PrimaryInterfaceResolver().currentInterfaceName()
        }
        readCounters = SystemInterfaceCounters.read
    }

    public init(
        interfaceName: @escaping () -> String?,
        readCounters: @escaping (String) -> InterfaceCounters?
    ) {
        self.interfaceName = interfaceName
        self.readCounters = readCounters
    }

    public func start(interval: TimeInterval) {
        stop()
        sampleOnce()
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sampleOnce()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        previous = nil
        smoothed = nil
    }

    public func sampleOnce() {
        guard let name = interfaceName(),
              let current = readCounters(name) else {
            previous = nil
            smoothed = nil
            onRate?(nil)
            return
        }

        defer { previous = current }
        guard let previous,
              let rawRate = RateCalculator.next(
                previous: previous,
                current: current
              ) else {
            onRate?(nil)
            return
        }

        let rate = TrafficRate(
            downloadBytesPerSecond: RateCalculator.smooth(
                previous: smoothed?.downloadBytesPerSecond,
                current: rawRate.downloadBytesPerSecond
            ),
            uploadBytesPerSecond: RateCalculator.smooth(
                previous: smoothed?.uploadBytesPerSecond,
                current: rawRate.uploadBytesPerSecond
            )
        )
        smoothed = rate
        onRate?(rate)
    }
}

enum SystemInterfaceCounters {
    static func read(named interface: String) -> InterfaceCounters? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return nil
        }
        defer { freeifaddrs(first) }

        for item in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let rawName = item.pointee.ifa_name,
                  String(cString: rawName) == interface,
                  let rawData = item.pointee.ifa_data else {
                continue
            }

            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            return InterfaceCounters(
                receivedBytes: UInt64(data.ifi_ibytes),
                sentBytes: UInt64(data.ifi_obytes),
                timestamp: Date().timeIntervalSinceReferenceDate
            )
        }

        return nil
    }
}
