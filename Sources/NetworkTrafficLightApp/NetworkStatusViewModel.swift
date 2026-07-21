import Combine
import NetworkTrafficLightCore

@MainActor
final class NetworkStatusViewModel: ObservableObject {
    @Published private(set) var indicator: IndicatorState = .gray
    @Published private(set) var rate: TrafficRate?

    let preferences: Preferences
    let launchAtLogin: LaunchAtLoginController
    let updates: UpdateController

    private let sampler: TrafficSampler
    private let healthMonitor: PathHealthMonitor
    private var pathState: PathState = .starting
    private var probeState: ProbeState = .notRun
    private var cancellables = Set<AnyCancellable>()

    init(
        preferences: Preferences = Preferences(),
        sampler: TrafficSampler = TrafficSampler(),
        healthMonitor: PathHealthMonitor = PathHealthMonitor()
    ) {
        self.preferences = preferences
        launchAtLogin = LaunchAtLoginController()
        updates = UpdateController()
        self.sampler = sampler
        self.healthMonitor = healthMonitor

        preferences.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        sampler.onRate = { [weak self] rate in
            self?.rate = rate
        }
        healthMonitor.onPathState = { [weak self] state in
            self?.pathState = state
            self?.updateIndicator()
        }
        healthMonitor.onProbeState = { [weak self] state in
            self?.probeState = state
            self?.updateIndicator()
        }

        restartMonitoring()
    }

    var displayedDownloadRate: String? {
        preferences.showDownloadRate
            ? RateFormatter.string(
                for: rate?.downloadBytesPerSecond,
                unit: displayUnit
            )
            : nil
    }

    var displayedUploadRate: String? {
        preferences.showUploadRate
            ? RateFormatter.string(
                for: rate?.uploadBytesPerSecond,
                unit: displayUnit
            )
            : nil
    }

    func restartMonitoring() {
        sampler.stop()
        healthMonitor.stop()
        rate = nil
        pathState = .starting
        probeState = .notRun
        updateIndicator()
        sampler.start(interval: preferences.sampleInterval)
        healthMonitor.start(healthChecksEnabled: preferences.healthChecksEnabled)
    }

    private func updateIndicator() {
        indicator = NetworkStatusReducer.indicator(
            path: pathState,
            probe: probeState,
            healthChecksEnabled: preferences.healthChecksEnabled
        )
    }

    private var displayUnit: RateDisplayUnit {
        preferences.useMegabitsPerSecond
            ? .megabitsPerSecond
            : .megabytesPerSecond
    }
}
