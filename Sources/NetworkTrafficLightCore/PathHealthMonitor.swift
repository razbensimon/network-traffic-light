import Foundation
import Network

@MainActor
public final class PathHealthMonitor {
    public var onPathState: ((PathState) -> Void)?
    public var onProbeState: ((ProbeState) -> Void)?

    private var monitor: NWPathMonitor?
    private var probeTimer: Timer?
    private var probeInFlight = false
    private var healthChecksEnabled = true

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
    }

    private func handlePathState(_ state: PathState) {
        onPathState?(state)
        guard state == .satisfied else {
            probeTimer?.invalidate()
            probeTimer = nil
            onProbeState?(.notRun)
            return
        }

        guard healthChecksEnabled else {
            onProbeState?(.notRun)
            return
        }

        onProbeState?(.pending)
        probe()
        probeTimer?.invalidate()
        probeTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.probe()
            }
        }
    }

    private func probe() {
        guard !probeInFlight,
              let url = URL(string: "https://captive.apple.com/hotspot-detect.html") else {
            return
        }

        probeInFlight = true
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let succeeded = error == nil && (200...399).contains(statusCode)

            Task { @MainActor in
                guard let self else {
                    return
                }

                self.probeInFlight = false
                self.onProbeState?(succeeded ? .succeeded : .failed)
            }
        }.resume()
    }
}
