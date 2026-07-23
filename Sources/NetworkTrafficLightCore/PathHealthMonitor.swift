import Foundation
import Network

@MainActor
public final class PathHealthMonitor {
    public var onPathState: ((PathState) -> Void)?
    public var onProbeUpdate: ((ProbePhase, [ProbeSample]) -> Void)?

    private var monitor: NWPathMonitor?
    private var probeTimer: Timer?
    private var probeInFlight = false
    private var healthChecksEnabled = true
    private var recentSamples: [ProbeSample] = []

    private static let probeInterval: TimeInterval = 10
    private static let maxSamples = 2

    public init() {}

    public func start(healthChecksEnabled: Bool) {
        stop()
        self.healthChecksEnabled = healthChecksEnabled

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let state: PathState = path.status == .satisfied ? .satisfied : .unsatisfied
            Task { @MainActor in
                self?.handlePathState(state)
            }
        }

        self.monitor = monitor
        monitor.start(queue: DispatchQueue(label: "local.networktrafficlight.health"))
    }

    public func stop() {
        monitor?.cancel()
        monitor = nil
        probeTimer?.invalidate()
        probeTimer = nil
        probeInFlight = false
        recentSamples = []
    }

    private func handlePathState(_ state: PathState) {
        onPathState?(state)
        guard state == .satisfied else {
            probeTimer?.invalidate()
            probeTimer = nil
            clearProbeHistory(phase: .notRun)
            return
        }

        guard healthChecksEnabled else {
            clearProbeHistory(phase: .notRun)
            return
        }

        recentSamples = []
        onProbeUpdate?(.pending, [])
        probe()
        probeTimer?.invalidate()
        probeTimer = Timer.scheduledTimer(
            withTimeInterval: Self.probeInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.probe()
            }
        }
    }

    private func clearProbeHistory(phase: ProbePhase) {
        recentSamples = []
        onProbeUpdate?(phase, [])
    }

    private func probe() {
        guard !probeInFlight,
              let url = URL(string: "https://captive.apple.com/hotspot-detect.html") else {
            return
        }

        probeInFlight = true
        let startedAt = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let succeeded = error == nil && (200...399).contains(statusCode)
            let duration = Date().timeIntervalSince(startedAt)

            Task { @MainActor in
                guard let self else {
                    return
                }

                self.probeInFlight = false
                self.appendSample(
                    ProbeSample(succeeded: succeeded, duration: duration)
                )
            }
        }.resume()
    }

    private func appendSample(_ sample: ProbeSample) {
        recentSamples.append(sample)
        if recentSamples.count > Self.maxSamples {
            recentSamples.removeFirst(recentSamples.count - Self.maxSamples)
        }
        onProbeUpdate?(.sampled, recentSamples)
    }
}
