# Network Traffic Light Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app that shows connection health by default and optionally displays live download and upload rates.

**Architecture:** A Swift Package executable hosts a SwiftUI `MenuBarExtra` and uses macOS system APIs for all monitoring. Small focused services resolve the primary interface, sample byte counters, and monitor path/probe health; a main-actor presentation model combines their output for the UI.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Network.framework, SystemConfiguration, XCTest, Swift Package Manager.

## Global Constraints

- Target macOS 13 or later; use no third-party dependencies.
- The app runs as an agent application with no Dock icon or main window.
- Default menu-bar content is only a colour dot; upload and download labels default to hidden and are independently configurable.
- Default sample interval is two seconds; supported values are 1, 2, 5, and 10 seconds.
- Use `getifaddrs`/`if_data` counters only; do not spawn shell processes, capture packets, request elevated privileges, or retain history.
- Run a five-second-timeout `HEAD` probe to `https://captive.apple.com/hotspot-detect.html` at most every 30 seconds when health checks are enabled. Do not issue probes when disabled.
- Do not create commits unless the user explicitly requests them.

---

## Planned File Structure

```text
Package.swift                                      # SwiftPM package definition
Sources/NetworkTrafficLight/
  NetworkTrafficLightApp.swift                     # Agent app and MenuBarExtra scene
  Domain/
    TrafficModels.swift                            # Counter, rate, and interface value types
    RateCalculator.swift                           # Delta/rate calculation and smoothing
    RateFormatter.swift                            # Binary rate formatting
    NetworkStatusReducer.swift                     # Maps path/probe state to dot state
  Services/
    PrimaryInterfaceResolver.swift                 # SystemConfiguration and getifaddrs selection
    TrafficSampler.swift                           # Interval-based primary-interface counters
    PathHealthMonitor.swift                        # NWPathMonitor and bounded HTTPS probe
  UI/
    Preferences.swift                              # Persisted display/interval settings
    MenuBarLabel.swift                             # Dot and optional rate label
    StatusPopover.swift                            # Status, controls, and quit action
    NetworkStatusViewModel.swift                   # Main-actor service/UI coordinator
Tests/NetworkTrafficLightTests/
  RateCalculatorTests.swift
  RateFormatterTests.swift
  NetworkStatusReducerTests.swift
  PrimaryInterfaceResolverTests.swift
Resources/Info.plist                               # App bundle agent metadata
Scripts/build-app.sh                               # Produces a distributable .app
README.md                                          # Build, install, and privacy instructions
```

### Task 1: Create the native package and distributable app shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/NetworkTrafficLight/NetworkTrafficLightApp.swift`
- Create: `Resources/Info.plist`
- Create: `Scripts/build-app.sh`
- Create: `README.md`

**Interfaces:**
- Produces executable product `NetworkTrafficLight`.
- Produces app bundle `build/NetworkTrafficLight.app` through `Scripts/build-app.sh`.
- Later tasks add the `NetworkStatusViewModel`, `MenuBarLabel`, and `StatusPopover` types referenced by the app shell.

- [ ] **Step 1: Add the package manifest**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkTrafficLight",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NetworkTrafficLight", targets: ["NetworkTrafficLight"])
    ],
    targets: [
        .executableTarget(name: "NetworkTrafficLight"),
        .testTarget(
            name: "NetworkTrafficLightTests",
            dependencies: ["NetworkTrafficLight"]
        )
    ]
)
```

- [ ] **Step 2: Add the agent application shell**

```swift
// Sources/NetworkTrafficLight/NetworkTrafficLightApp.swift
import AppKit
import SwiftUI

@main
struct NetworkTrafficLightApp: App {
    @StateObject private var model = NetworkStatusViewModel.live()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusPopover(model: model)
        } label: {
            MenuBarLabel(
                indicator: model.indicator,
                downloadRate: model.displayDownloadRate,
                uploadRate: model.displayUploadRate
            )
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Add bundle metadata and packaging script**

```xml
<!-- Resources/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Network Traffic Light</string>
    <key>CFBundleExecutable</key>
    <string>NetworkTrafficLight</string>
    <key>CFBundleIdentifier</key>
    <string>local.networktrafficlight.app</string>
    <key>CFBundleName</key>
    <string>NetworkTrafficLight</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

```bash
#!/usr/bin/env bash
# Scripts/build-app.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

bin_dir="$(swift build -c release --show-bin-path)"
app="$root/build/NetworkTrafficLight.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/NetworkTrafficLight" "$app/Contents/MacOS/NetworkTrafficLight"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
echo "Built $app"
```

Make the script executable with `chmod +x Scripts/build-app.sh`.

- [ ] **Step 4: Add the initial README**

```markdown
# Network Traffic Light

A local-only macOS menu-bar indicator for connection health and optional
live upload/download rates.

## Requirements

- macOS 13+
- Xcode Command Line Tools with Swift 6

## Run during development

```bash
swift run NetworkTrafficLight
```

## Build an app bundle

```bash
./Scripts/build-app.sh
open build/NetworkTrafficLight.app
```

The app reads aggregate operating-system interface byte counters. It does not
capture packets, inspect traffic, retain history, send telemetry, or require
administrator privileges. When connection health checks are enabled, it sends
one `HEAD` request to Apple's captive-network endpoint every 30 seconds.
```

- [ ] **Step 5: Verify the scaffold compiles after Tasks 2–5 types exist**

Run: `swift build`

Expected: `Build complete!` with no package dependencies downloaded.

### Task 2: Implement pure traffic-rate domain logic with tests

**Files:**
- Create: `Sources/NetworkTrafficLight/Domain/TrafficModels.swift`
- Create: `Sources/NetworkTrafficLight/Domain/RateCalculator.swift`
- Create: `Sources/NetworkTrafficLight/Domain/RateFormatter.swift`
- Create: `Tests/NetworkTrafficLightTests/RateCalculatorTests.swift`
- Create: `Tests/NetworkTrafficLightTests/RateFormatterTests.swift`

**Interfaces:**
- Produces `InterfaceCounters`, `TrafficRate`, `RateCalculator`, and `RateFormatter`.
- `TrafficSampler` in Task 4 consumes `RateCalculator.next(previous:current:)`.
- `NetworkStatusViewModel` in Task 5 consumes `TrafficRate` and `RateFormatter.string(for:)`.

- [ ] **Step 1: Write failing rate-calculation tests**

```swift
// Tests/NetworkTrafficLightTests/RateCalculatorTests.swift
import XCTest
@testable import NetworkTrafficLight

final class RateCalculatorTests: XCTestCase {
    func testCalculatesReceiveAndTransmitRatesFromElapsedTime() {
        let previous = InterfaceCounters(receivedBytes: 1_000, sentBytes: 500, timestamp: 10)
        let current = InterfaceCounters(receivedBytes: 5_096, sentBytes: 1_524, timestamp: 12)

        let rate = RateCalculator.next(previous: previous, current: current)

        XCTAssertEqual(rate?.downloadBytesPerSecond, 2_048)
        XCTAssertEqual(rate?.uploadBytesPerSecond, 512)
    }

    func testRejectsCounterResetAndNonIncreasingTime() {
        let previous = InterfaceCounters(receivedBytes: 100, sentBytes: 100, timestamp: 10)

        XCTAssertNil(RateCalculator.next(
            previous: previous,
            current: InterfaceCounters(receivedBytes: 99, sentBytes: 200, timestamp: 11)
        ))
        XCTAssertNil(RateCalculator.next(
            previous: previous,
            current: InterfaceCounters(receivedBytes: 200, sentBytes: 200, timestamp: 10)
        ))
    }

    func testSmoothsNewRatesWithAlphaOneHalf() {
        XCTAssertEqual(
            RateCalculator.smooth(previous: 100, current: 300, alpha: 0.5),
            200
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter RateCalculatorTests`

Expected: FAIL because the domain types do not exist.

- [ ] **Step 3: Add the minimal domain implementation**

```swift
// Sources/NetworkTrafficLight/Domain/TrafficModels.swift
import Foundation

struct InterfaceCounters: Equatable, Sendable {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let timestamp: TimeInterval
}

struct TrafficRate: Equatable, Sendable {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}
```

```swift
// Sources/NetworkTrafficLight/Domain/RateCalculator.swift
import Foundation

enum RateCalculator {
    static func next(previous: InterfaceCounters, current: InterfaceCounters) -> TrafficRate? {
        let elapsed = current.timestamp - previous.timestamp
        guard elapsed > 0,
              current.receivedBytes >= previous.receivedBytes,
              current.sentBytes >= previous.sentBytes else {
            return nil
        }

        return TrafficRate(
            downloadBytesPerSecond: Double(current.receivedBytes - previous.receivedBytes) / elapsed,
            uploadBytesPerSecond: Double(current.sentBytes - previous.sentBytes) / elapsed
        )
    }

    static func smooth(previous: Double?, current: Double, alpha: Double = 0.5) -> Double {
        guard let previous else { return current }
        return alpha * current + (1 - alpha) * previous
    }
}
```

- [ ] **Step 4: Add formatter tests and implementation**

```swift
// Tests/NetworkTrafficLightTests/RateFormatterTests.swift
import XCTest
@testable import NetworkTrafficLight

final class RateFormatterTests: XCTestCase {
    func testFormatsNilAndBinaryUnits() {
        XCTAssertEqual(RateFormatter.string(for: nil), "—")
        XCTAssertEqual(RateFormatter.string(for: 0), "0 KB/s")
        XCTAssertEqual(RateFormatter.string(for: 1_536), "1.5 KB/s")
        XCTAssertEqual(RateFormatter.string(for: 4_194_304), "4 MB/s")
    }
}
```

```swift
// Sources/NetworkTrafficLight/Domain/RateFormatter.swift
import Foundation

enum RateFormatter {
    static func string(for bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else { return "—" }
        let units = ["KB/s", "MB/s", "GB/s"]
        var value = max(0, bytesPerSecond) / 1_024
        var index = 0

        while value >= 1_024, index < units.count - 1 {
            value /= 1_024
            index += 1
        }

        let precision = value >= 10 || value.rounded() == value ? 0 : 1
        return String(format: "%.\(precision)f %@", value, units[index])
    }
}
```

- [ ] **Step 5: Run domain tests**

Run: `swift test --filter 'RateCalculatorTests|RateFormatterTests'`

Expected: all four tests PASS.

### Task 3: Implement deterministic interface selection and status reduction

**Files:**
- Create: `Sources/NetworkTrafficLight/Domain/NetworkStatusReducer.swift`
- Create: `Sources/NetworkTrafficLight/Services/PrimaryInterfaceResolver.swift`
- Create: `Tests/NetworkTrafficLightTests/NetworkStatusReducerTests.swift`
- Create: `Tests/NetworkTrafficLightTests/PrimaryInterfaceResolverTests.swift`

**Interfaces:**
- Produces `InterfaceCandidate`, `PrimaryInterfaceSelector`, `PathState`, `ProbeState`, and `IndicatorState`.
- Task 4 consumes `PrimaryInterfaceResolver.currentInterfaceName()`.
- Task 5 consumes `NetworkStatusReducer.indicator(path:probe:healthChecksEnabled:)`.

- [ ] **Step 1: Write failing selection and indicator tests**

```swift
// Tests/NetworkTrafficLightTests/PrimaryInterfaceResolverTests.swift
import XCTest
@testable import NetworkTrafficLight

final class PrimaryInterfaceResolverTests: XCTestCase {
    func testPrefersConfiguredPrimaryInterfaceWhenEligible() {
        let candidates = [
            InterfaceCandidate(name: "en0", isUp: true, isRunning: true, isLoopback: false, isPointToPoint: false),
            InterfaceCandidate(name: "en1", isUp: true, isRunning: true, isLoopback: false, isPointToPoint: false)
        ]

        XCTAssertEqual(PrimaryInterfaceSelector.select(configuredName: "en1", candidates: candidates), "en1")
    }

    func testFallsBackToFirstEligibleInterface() {
        let candidates = [
            InterfaceCandidate(name: "lo0", isUp: true, isRunning: true, isLoopback: true, isPointToPoint: false),
            InterfaceCandidate(name: "en0", isUp: true, isRunning: true, isLoopback: false, isPointToPoint: false)
        ]

        XCTAssertEqual(PrimaryInterfaceSelector.select(configuredName: nil, candidates: candidates), "en0")
    }
}
```

```swift
// Tests/NetworkTrafficLightTests/NetworkStatusReducerTests.swift
import XCTest
@testable import NetworkTrafficLight

final class NetworkStatusReducerTests: XCTestCase {
    func testUsesRedWithoutUsablePath() {
        XCTAssertEqual(
            NetworkStatusReducer.indicator(path: .unsatisfied, probe: .notRun, healthChecksEnabled: true),
            .red
        )
    }

    func testUsesGreenForSatisfiedPathWhenChecksDisabled() {
        XCTAssertEqual(
            NetworkStatusReducer.indicator(path: .satisfied, probe: .notRun, healthChecksEnabled: false),
            .green
        )
    }

    func testUsesYellowForPendingOrFailedProbe() {
        XCTAssertEqual(
            NetworkStatusReducer.indicator(path: .satisfied, probe: .pending, healthChecksEnabled: true),
            .yellow
        )
        XCTAssertEqual(
            NetworkStatusReducer.indicator(path: .satisfied, probe: .failed, healthChecksEnabled: true),
            .yellow
        )
    }
}
```

- [ ] **Step 2: Run selection/reducer tests to verify failure**

Run: `swift test --filter 'PrimaryInterfaceResolverTests|NetworkStatusReducerTests'`

Expected: FAIL because the resolver and reducer are missing.

- [ ] **Step 3: Implement pure models, selector, and reducer**

```swift
// Sources/NetworkTrafficLight/Domain/NetworkStatusReducer.swift
enum PathState: Equatable, Sendable {
    case starting
    case satisfied
    case unsatisfied
}

enum ProbeState: Equatable, Sendable {
    case notRun
    case pending
    case succeeded
    case failed
}

enum IndicatorState: Equatable, Sendable {
    case gray
    case green
    case yellow
    case red
}

enum NetworkStatusReducer {
    static func indicator(path: PathState, probe: ProbeState, healthChecksEnabled: Bool) -> IndicatorState {
        switch path {
        case .starting:
            return .gray
        case .unsatisfied:
            return .red
        case .satisfied where !healthChecksEnabled:
            return .green
        case .satisfied where probe == .succeeded:
            return .green
        case .satisfied:
            return .yellow
        }
    }
}
```

```swift
// Sources/NetworkTrafficLight/Services/PrimaryInterfaceResolver.swift
import Foundation
import SystemConfiguration

struct InterfaceCandidate: Equatable, Sendable {
    let name: String
    let isUp: Bool
    let isRunning: Bool
    let isLoopback: Bool
    let isPointToPoint: Bool

    var isEligible: Bool {
        isUp && isRunning && !isLoopback && !isPointToPoint
    }
}

enum PrimaryInterfaceSelector {
    static func select(configuredName: String?, candidates: [InterfaceCandidate]) -> String? {
        if let configuredName,
           candidates.first(where: { $0.name == configuredName && $0.isEligible }) != nil {
            return configuredName
        }
        return candidates.first(where: \.isEligible)?.name
    }
}

struct PrimaryInterfaceResolver {
    let candidates: () -> [InterfaceCandidate]
    let configuredName: () -> String?

    init(
        candidates: @escaping () -> [InterfaceCandidate] = SystemInterfaces.candidates,
        configuredName: @escaping () -> String? = SystemInterfaces.primaryName
    ) {
        self.candidates = candidates
        self.configuredName = configuredName
    }

    func currentInterfaceName() -> String? {
        PrimaryInterfaceSelector.select(configuredName: configuredName(), candidates: candidates())
    }
}

enum SystemInterfaces {
    static func primaryName() -> String? {
        let key = "State:/Network/Global/IPv4" as CFString
        let value = SCDynamicStoreCopyValue(nil, key) as? [String: Any]
        return value?["PrimaryInterface"] as? String
    }

    static func candidates() -> [InterfaceCandidate] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(first) }

        return sequence(first: first, next: { $0.pointee.ifa_next }).compactMap { item in
            let flags = Int32(item.pointee.ifa_flags)
            guard let rawName = item.pointee.ifa_name else { return nil }
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
```

- [ ] **Step 4: Run selection and reducer tests**

Run: `swift test --filter 'PrimaryInterfaceResolverTests|NetworkStatusReducerTests'`

Expected: all five tests PASS.

### Task 4: Implement bounded system monitoring services

**Files:**
- Create: `Sources/NetworkTrafficLight/Services/TrafficSampler.swift`
- Create: `Sources/NetworkTrafficLight/Services/PathHealthMonitor.swift`

**Interfaces:**
- Consumes `PrimaryInterfaceResolver`, `InterfaceCounters`, `TrafficRate`, `RateCalculator`, `PathState`, and `ProbeState`.
- Produces `TrafficSampler.onRate: ((TrafficRate?) -> Void)?`, `PathHealthMonitor.onPathState: ((PathState) -> Void)?`, and `PathHealthMonitor.onProbeState: ((ProbeState) -> Void)?`.
- `NetworkStatusViewModel` in Task 5 owns, starts, and stops both services.

- [ ] **Step 1: Implement interface-counter reads and a cancellable sampler**

```swift
// Sources/NetworkTrafficLight/Services/TrafficSampler.swift
import Foundation

final class TrafficSampler {
    var onRate: ((TrafficRate?) -> Void)?

    private let resolver: PrimaryInterfaceResolver
    private let queue = DispatchQueue(label: "local.networktrafficlight.sampler")
    private var timer: DispatchSourceTimer?
    private var previous: InterfaceCounters?
    private var smoothed: TrafficRate?

    init(resolver: PrimaryInterfaceResolver = PrimaryInterfaceResolver()) {
        self.resolver = resolver
    }

    func start(interval: TimeInterval) {
        stop()
        sample()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in self?.sample() }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        previous = nil
        smoothed = nil
    }

    private func sample() {
        guard let name = resolver.currentInterfaceName(),
              let current = SystemInterfaceCounters.read(named: name) else {
            previous = nil
            smoothed = nil
            onRate?(nil)
            return
        }
        defer { previous = current }
        guard let previous, let raw = RateCalculator.next(previous: previous, current: current) else {
            onRate?(nil)
            return
        }
        let rate = TrafficRate(
            downloadBytesPerSecond: RateCalculator.smooth(
                previous: smoothed?.downloadBytesPerSecond,
                current: raw.downloadBytesPerSecond
            ),
            uploadBytesPerSecond: RateCalculator.smooth(
                previous: smoothed?.uploadBytesPerSecond,
                current: raw.uploadBytesPerSecond
            )
        )
        smoothed = rate
        onRate?(rate)
    }
}

enum SystemInterfaceCounters {
    static func read(named interface: String) -> InterfaceCounters? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(first) }

        for item in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let rawName = item.pointee.ifa_name,
                  String(cString: rawName) == interface,
                  item.pointee.ifa_data != nil else {
                continue
            }
            let data = item.pointee.ifa_data.assumingMemoryBound(to: if_data.self).pointee
            return InterfaceCounters(
                receivedBytes: UInt64(data.ifi_ibytes),
                sentBytes: UInt64(data.ifi_obytes),
                timestamp: Date().timeIntervalSinceReferenceDate
            )
        }
        return nil
    }
}
```

- [ ] **Step 2: Implement path monitoring and non-overlapping health probes**

```swift
// Sources/NetworkTrafficLight/Services/PathHealthMonitor.swift
import Foundation
import Network

final class PathHealthMonitor {
    var onPathState: ((PathState) -> Void)?
    var onProbeState: ((ProbeState) -> Void)?

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "local.networktrafficlight.health")
    private var probeTimer: DispatchSourceTimer?
    private var healthChecksEnabled = true
    private var probeInFlight = false

    func start(healthChecksEnabled: Bool) {
        stop()
        self.healthChecksEnabled = healthChecksEnabled
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handle(path.status == .satisfied ? .satisfied : .unsatisfied)
        }
        self.monitor = monitor
        monitor.start(queue: queue)
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
        probeTimer?.cancel()
        probeTimer = nil
        probeInFlight = false
    }

    private func handle(_ state: PathState) {
        onPathState?(state)
        guard state == .satisfied, healthChecksEnabled else { return }
        onProbeState?(.pending)
        probe()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in self?.probe() }
        probeTimer?.cancel()
        probeTimer = timer
        timer.resume()
    }

    private func probe() {
        guard !probeInFlight,
              let url = URL(string: "https://captive.apple.com/hotspot-detect.html") else { return }
        probeInFlight = true
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }
            self.queue.async {
                self.probeInFlight = false
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                self.onProbeState?(error == nil && (200...399).contains(code) ? .succeeded : .failed)
            }
        }.resume()
    }
}
```

- [ ] **Step 3: Perform manual service verification**

Run: `swift build`

Expected: `Build complete!`.

Then temporarily invoke `TrafficSampler.start(interval: 1)` from a small debug harness and verify that:

1. the first callback is `nil`,
2. a later callback is non-`nil` after traffic is generated,
3. changing the selected interface returns to a `nil` baseline,
4. disabling health checks results in no request in Instruments Network profiling.

### Task 5: Build the menu-bar presentation, preferences, and lifecycle integration

**Files:**
- Create: `Sources/NetworkTrafficLight/UI/Preferences.swift`
- Create: `Sources/NetworkTrafficLight/UI/NetworkStatusViewModel.swift`
- Create: `Sources/NetworkTrafficLight/UI/MenuBarLabel.swift`
- Create: `Sources/NetworkTrafficLight/UI/StatusPopover.swift`
- Modify: `Sources/NetworkTrafficLight/NetworkTrafficLightApp.swift`

**Interfaces:**
- Consumes all domain types and monitoring services.
- Produces the `NetworkStatusViewModel.live()` factory required by Task 1.
- Menu-bar label accepts the `IndicatorState` plus optional formatted strings; hidden settings produce `nil` strings.

- [ ] **Step 1: Implement persisted settings**

```swift
// Sources/NetworkTrafficLight/UI/Preferences.swift
import Combine
import Foundation

final class Preferences: ObservableObject {
    @Published var showDownloadRate: Bool { didSet { store.set(showDownloadRate, forKey: "showDownloadRate") } }
    @Published var showUploadRate: Bool { didSet { store.set(showUploadRate, forKey: "showUploadRate") } }
    @Published var sampleInterval: TimeInterval { didSet { store.set(sampleInterval, forKey: "sampleInterval") } }
    @Published var healthChecksEnabled: Bool { didSet { store.set(healthChecksEnabled, forKey: "healthChecksEnabled") } }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        showDownloadRate = store.object(forKey: "showDownloadRate") as? Bool ?? false
        showUploadRate = store.object(forKey: "showUploadRate") as? Bool ?? false
        sampleInterval = store.object(forKey: "sampleInterval") as? TimeInterval ?? 2
        healthChecksEnabled = store.object(forKey: "healthChecksEnabled") as? Bool ?? true
    }
}
```

- [ ] **Step 2: Implement the main-actor coordinator**

```swift
// Sources/NetworkTrafficLight/UI/NetworkStatusViewModel.swift
import Combine
import SwiftUI

@MainActor
final class NetworkStatusViewModel: ObservableObject {
    @Published private(set) var indicator: IndicatorState = .gray
    @Published private(set) var rate: TrafficRate?
    let preferences: Preferences

    private let sampler: TrafficSampler
    private let health: PathHealthMonitor
    private var path: PathState = .starting
    private var probe: ProbeState = .notRun

    static func live() -> NetworkStatusViewModel {
        NetworkStatusViewModel(preferences: Preferences(), sampler: TrafficSampler(), health: PathHealthMonitor())
    }

    init(preferences: Preferences, sampler: TrafficSampler, health: PathHealthMonitor) {
        self.preferences = preferences
        self.sampler = sampler
        self.health = health
        sampler.onRate = { [weak self] rate in
            Task { @MainActor in self?.rate = rate }
        }
        health.onPathState = { [weak self] path in
            Task { @MainActor in
                self?.path = path
                self?.refreshIndicator()
            }
        }
        health.onProbeState = { [weak self] probe in
            Task { @MainActor in
                self?.probe = probe
                self?.refreshIndicator()
            }
        }
        start()
    }

    var displayDownloadRate: String? {
        preferences.showDownloadRate ? RateFormatter.string(for: rate?.downloadBytesPerSecond) : nil
    }

    var displayUploadRate: String? {
        preferences.showUploadRate ? RateFormatter.string(for: rate?.uploadBytesPerSecond) : nil
    }

    func restartMonitoring() {
        sampler.stop()
        health.stop()
        start()
    }

    private func start() {
        sampler.start(interval: preferences.sampleInterval)
        health.start(healthChecksEnabled: preferences.healthChecksEnabled)
        refreshIndicator()
    }

    private func refreshIndicator() {
        indicator = NetworkStatusReducer.indicator(
            path: path,
            probe: probe,
            healthChecksEnabled: preferences.healthChecksEnabled
        )
    }

    deinit {
        sampler.stop()
        health.stop()
    }
}
```

- [ ] **Step 3: Implement the dot, optional labels, and popover**

```swift
// Sources/NetworkTrafficLight/UI/MenuBarLabel.swift
import SwiftUI

struct MenuBarLabel: View {
    let indicator: IndicatorState
    let downloadRate: String?
    let uploadRate: String?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .accessibilityLabel(accessibilityText)
            if let downloadRate { Text("↓ \(downloadRate)").monospacedDigit() }
            if let uploadRate { Text("↑ \(uploadRate)").monospacedDigit() }
        }
    }

    private var color: Color {
        switch indicator {
        case .gray: .gray
        case .green: .green
        case .yellow: .yellow
        case .red: .red
        }
    }

    private var accessibilityText: String {
        switch indicator {
        case .gray: "Network status is starting"
        case .green: "Network is healthy"
        case .yellow: "Network health is uncertain"
        case .red: "Network is unavailable"
        }
    }
}
```

```swift
// Sources/NetworkTrafficLight/UI/StatusPopover.swift
import AppKit
import SwiftUI

struct StatusPopover: View {
    @ObservedObject var model: NetworkStatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusText).font(.headline)
            LabeledContent("Download", value: RateFormatter.string(for: model.rate?.downloadBytesPerSecond))
            LabeledContent("Upload", value: RateFormatter.string(for: model.rate?.uploadBytesPerSecond))
            Divider()
            Toggle("Show download rate", isOn: $model.preferences.showDownloadRate)
            Toggle("Show upload rate", isOn: $model.preferences.showUploadRate)
            Toggle("Connection health check", isOn: $model.preferences.healthChecksEnabled)
                .onChange(of: model.preferences.healthChecksEnabled) { _ in model.restartMonitoring() }
            Picker("Sampling interval", selection: $model.preferences.sampleInterval) {
                Text("1 second").tag(TimeInterval(1))
                Text("2 seconds").tag(TimeInterval(2))
                Text("5 seconds").tag(TimeInterval(5))
                Text("10 seconds").tag(TimeInterval(10))
            }
            .onChange(of: model.preferences.sampleInterval) { _ in model.restartMonitoring() }
            Divider()
            Button("Quit Network Traffic Light") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 290)
    }

    private var statusText: String {
        switch model.indicator {
        case .gray: "Starting network monitor"
        case .green: "Network healthy"
        case .yellow: "Network health uncertain"
        case .red: "No usable network path"
        }
    }
}
```

- [ ] **Step 4: Build and exercise the app bundle**

Run:

```bash
swift test
./Scripts/build-app.sh
open build/NetworkTrafficLight.app
```

Expected:

- all unit tests PASS;
- the app has no Dock icon;
- the initial menu-bar item is only a dot;
- each display toggle immediately adds/removes only its matching rate label;
- the app exits from the popover’s Quit button.

### Task 6: Verify power, network, and platform behaviour

**Files:**
- Modify: `README.md`

**Interfaces:**
- No new code interfaces.
- Documents the final tested behaviour and known health-check boundary.

- [ ] **Step 1: Test the required network-state transitions manually**

1. With Wi-Fi connected and health checks enabled, wait for a green dot.
2. Disable health checks and confirm the dot remains green while the path is satisfied.
3. Turn Wi-Fi off and confirm the dot becomes red.
4. Turn Wi-Fi on and confirm the dot becomes yellow while the probe is pending, then green after it succeeds.
5. Generate a download and upload; enable the matching labels separately and together.
6. Change the sampling interval, quit, relaunch, and confirm all settings persist.
7. Put the Mac to sleep, wake it, and confirm the first rate is unavailable before the next valid sample rather than displaying a stale or extreme rate.

- [ ] **Step 2: Measure idle cost and inspect requests**

Run the packaged app with default settings, then use Activity Monitor for five minutes and Instruments’ Network template for at least 90 seconds.

Expected:

- CPU remains effectively idle between timer events;
- memory remains steady;
- no recurring child processes are created;
- at most one small `HEAD` probe occurs every 30 seconds;
- disabling the health check produces no network probe.

- [ ] **Step 3: Document verification and privacy behaviour**

Append this section to `README.md`:

```markdown
## Verification checklist

- The default menu-bar item is a colour dot only.
- Upload and download labels can be enabled independently and persist.
- The app samples only the primary interface’s aggregate byte counters.
- Rates reset after a sleep/wake or interface change until a valid delta exists.
- A health probe is bounded to five seconds and runs no more than once per
  30 seconds when enabled; disabling it sends no probe.
```

- [ ] **Step 4: Run the full final verification**

Run:

```bash
swift test
swift build -c release
./Scripts/build-app.sh
```

Expected: all tests PASS, release build completes, and
`build/NetworkTrafficLight.app/Contents/MacOS/NetworkTrafficLight` exists.

## Plan Self-Review

- **Spec coverage:** Tasks 1–5 cover the macOS agent shell, dot-only default,
  independent labels, all sample intervals, counter sampling, health check,
  popover, persistence, sleep/interface-safe baseline reset, and app bundle.
  Task 6 verifies performance, privacy, and platform transitions.
- **Placeholder scan:** no TBD/TODO markers or unspecified endpoints remain.
- **Type consistency:** `TrafficRate`, `IndicatorState`, `PathState`,
  `ProbeState`, `PrimaryInterfaceResolver`, and both service callback
  signatures are defined before their consumers.
