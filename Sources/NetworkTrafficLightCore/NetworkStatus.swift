import Foundation

public enum PathState: Equatable, Sendable {
    case starting
    case satisfied
    case unsatisfied
}

public enum ProbePhase: Equatable, Sendable {
    case notRun
    case pending
    case sampled
}

public struct ProbeSample: Equatable, Sendable {
    public let succeeded: Bool
    public let duration: TimeInterval

    public init(succeeded: Bool, duration: TimeInterval) {
        self.succeeded = succeeded
        self.duration = duration
    }
}

public enum IndicatorState: Equatable, Sendable {
    case gray
    case green
    case yellow
    case red
}

public enum NetworkStatusReducer {
    public static let greenMaxLatency: TimeInterval = 0.8
    public static let yellowMaxLatency: TimeInterval = 3.0
    public static let streakWindow = 2

    public static func indicator(
        path: PathState,
        phase: ProbePhase,
        recent: [ProbeSample],
        healthChecksEnabled: Bool
    ) -> IndicatorState {
        switch path {
        case .starting:
            .gray
        case .unsatisfied:
            .red
        case .satisfied where !healthChecksEnabled:
            .green
        case .satisfied where phase == .pending || phase == .notRun:
            .yellow
        case .satisfied:
            qualityIndicator(recent: recent)
        }
    }

    private static func qualityIndicator(recent: [ProbeSample]) -> IndicatorState {
        let window = Array(recent.suffix(streakWindow))
        guard let latest = window.last else {
            return .yellow
        }

        let failureCount = window.filter { !$0.succeeded }.count
        if failureCount >= streakWindow {
            return .red
        }
        if failureCount == 1 {
            return .yellow
        }

        guard latest.succeeded else {
            return .yellow
        }

        if latest.duration >= yellowMaxLatency {
            return .red
        }
        if latest.duration >= greenMaxLatency {
            return .yellow
        }
        return .green
    }
}
