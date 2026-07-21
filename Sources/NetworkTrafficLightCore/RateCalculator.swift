import Foundation

public enum RateCalculator {
    public static func next(
        previous: InterfaceCounters,
        current: InterfaceCounters
    ) -> TrafficRate? {
        let elapsed = current.timestamp - previous.timestamp

        guard elapsed > 0,
              current.receivedBytes >= previous.receivedBytes,
              current.sentBytes >= previous.sentBytes else {
            return nil
        }

        return TrafficRate(
            downloadBytesPerSecond: Double(
                current.receivedBytes - previous.receivedBytes
            ) / elapsed,
            uploadBytesPerSecond: Double(
                current.sentBytes - previous.sentBytes
            ) / elapsed
        )
    }

    public static func smooth(
        previous: Double?,
        current: Double,
        alpha: Double = 0.5
    ) -> Double {
        guard let previous else {
            return current
        }

        return alpha * current + (1 - alpha) * previous
    }
}
