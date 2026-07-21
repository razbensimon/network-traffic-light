import Foundation

public struct InterfaceCounters: Equatable, Sendable {
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let timestamp: TimeInterval

    public init(
        receivedBytes: UInt64,
        sentBytes: UInt64,
        timestamp: TimeInterval
    ) {
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.timestamp = timestamp
    }
}

public struct TrafficRate: Equatable, Sendable {
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double

    public init(
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double
    ) {
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}
