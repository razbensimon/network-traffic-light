import Foundation
import NetworkTrafficLightCore

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    precondition(actual == expected, "\(message): expected \(expected), got \(actual)")
}

func expectNil<T>(_ value: T?, _ message: String) {
    precondition(value == nil, "\(message): expected nil, got \(String(describing: value))")
}

let previous = InterfaceCounters(
    receivedBytes: 1_000,
    sentBytes: 500,
    timestamp: 10
)
let current = InterfaceCounters(
    receivedBytes: 5_096,
    sentBytes: 1_524,
    timestamp: 12
)
let rate = RateCalculator.next(previous: previous, current: current)

expectEqual(rate?.downloadBytesPerSecond, 2_048, "download rate")
expectEqual(rate?.uploadBytesPerSecond, 512, "upload rate")
expectNil(
    RateCalculator.next(
        previous: previous,
        current: InterfaceCounters(
            receivedBytes: 999,
            sentBytes: 1_524,
            timestamp: 12
        )
    ),
    "counter reset"
)
expectNil(
    RateCalculator.next(
        previous: previous,
        current: InterfaceCounters(
            receivedBytes: 5_096,
            sentBytes: 1_524,
            timestamp: 10
        )
    ),
    "non-increasing timestamp"
)
expectEqual(
    RateCalculator.smooth(previous: 100, current: 300, alpha: 0.5),
    200,
    "smoothed rate"
)
expectEqual(RateFormatter.string(for: nil), "—", "unavailable rate")
expectEqual(RateFormatter.string(for: 0), "0 KB/s", "zero rate")
expectEqual(RateFormatter.string(for: 1_536), "1.5 KB/s", "kilobyte rate")
expectEqual(RateFormatter.string(for: 4_194_304), "4 MB/s", "megabyte rate")
expectEqual(
    RateFormatter.string(for: 4_194_304, unit: .megabitsPerSecond),
    "33.6 Mbps",
    "megabits per second"
)

let candidates = [
    InterfaceCandidate(
        name: "lo0",
        isUp: true,
        isRunning: true,
        isLoopback: true,
        isPointToPoint: false
    ),
    InterfaceCandidate(
        name: "en0",
        isUp: true,
        isRunning: true,
        isLoopback: false,
        isPointToPoint: false
    ),
    InterfaceCandidate(
        name: "en1",
        isUp: true,
        isRunning: true,
        isLoopback: false,
        isPointToPoint: false
    )
]
expectEqual(
    PrimaryInterfaceSelector.select(configuredName: "en1", candidates: candidates),
    "en1",
    "configured primary interface"
)
expectEqual(
    PrimaryInterfaceSelector.select(configuredName: nil, candidates: candidates),
    "en0",
    "fallback primary interface"
)
expectEqual(
    NetworkStatusReducer.indicator(
        path: .unsatisfied,
        probe: .notRun,
        healthChecksEnabled: true
    ),
    .red,
    "unusable path"
)
expectEqual(
    NetworkStatusReducer.indicator(
        path: .satisfied,
        probe: .notRun,
        healthChecksEnabled: false
    ),
    .green,
    "satisfied path without health checks"
)
expectEqual(
    NetworkStatusReducer.indicator(
        path: .satisfied,
        probe: .pending,
        healthChecksEnabled: true
    ),
    .yellow,
    "pending health probe"
)

let samplerCounters = [
    InterfaceCounters(receivedBytes: 1_000, sentBytes: 500, timestamp: 10),
    InterfaceCounters(receivedBytes: 5_096, sentBytes: 1_524, timestamp: 12)
]
var samplerIndex = 0
var sampledRates: [TrafficRate?] = []
let sampler = TrafficSampler(
    interfaceName: { "en0" },
    readCounters: { _ in
        defer { samplerIndex += 1 }
        return samplerCounters[min(samplerIndex, samplerCounters.count - 1)]
    }
)
sampler.onRate = { sampledRates.append($0) }
sampler.sampleOnce()
sampler.sampleOnce()

expectEqual(sampledRates.count, 2, "sample callback count")
expectNil(sampledRates[0], "first sample baseline")
expectEqual(sampledRates[1]?.downloadBytesPerSecond, 2_048, "sampled download rate")
expectEqual(sampledRates[1]?.uploadBytesPerSecond, 512, "sampled upload rate")

print("Domain and sampler checks passed")
