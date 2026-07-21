import Foundation

public enum PathState: Equatable, Sendable {
    case starting
    case satisfied
    case unsatisfied
}

public enum ProbeState: Equatable, Sendable {
    case notRun
    case pending
    case succeeded
    case failed
}

public enum IndicatorState: Equatable, Sendable {
    case gray
    case green
    case yellow
    case red
}

public enum NetworkStatusReducer {
    public static func indicator(
        path: PathState,
        probe: ProbeState,
        healthChecksEnabled: Bool
    ) -> IndicatorState {
        switch path {
        case .starting:
            .gray
        case .unsatisfied:
            .red
        case .satisfied where !healthChecksEnabled || probe == .succeeded:
            .green
        case .satisfied:
            .yellow
        }
    }
}
