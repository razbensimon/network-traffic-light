import Foundation

public enum RateDisplayUnit: Sendable {
    case megabytesPerSecond
    case megabitsPerSecond
}

public enum RateFormatter {
    public static func string(
        for bytesPerSecond: Double?,
        unit: RateDisplayUnit = .megabytesPerSecond
    ) -> String {
        guard let bytesPerSecond else {
            return "—"
        }

        switch unit {
        case .megabytesPerSecond:
            return megabytesString(for: bytesPerSecond)
        case .megabitsPerSecond:
            return megabitsString(for: bytesPerSecond)
        }
    }

    private static func megabytesString(for bytesPerSecond: Double) -> String {
        let units = ["KB/s", "MB/s", "GB/s"]
        var value = max(0, bytesPerSecond) / 1_024
        var unitIndex = 0

        while value >= 1_024, unitIndex < units.count - 1 {
            value /= 1_024
            unitIndex += 1
        }

        let precision = value >= 10 || value.rounded() == value ? 0 : 1
        return String(format: "%.\(precision)f %@", value, units[unitIndex])
    }

    private static func megabitsString(for bytesPerSecond: Double) -> String {
        let units = ["Mbps", "Gbps"]
        var value = max(0, bytesPerSecond) * 8 / 1_000_000
        var unitIndex = 0

        while value >= 1_000, unitIndex < units.count - 1 {
            value /= 1_000
            unitIndex += 1
        }

        let precision = value >= 100 || value.rounded() == value ? 0 : 1
        return String(format: "%.\(precision)f %@", value, units[unitIndex])
    }
}
