import Combine
import Foundation

@MainActor
final class Preferences: ObservableObject {
    @Published var showDownloadRate: Bool {
        didSet { store.set(showDownloadRate, forKey: Keys.showDownloadRate) }
    }

    @Published var showUploadRate: Bool {
        didSet { store.set(showUploadRate, forKey: Keys.showUploadRate) }
    }

    @Published var useMegabitsPerSecond: Bool {
        didSet { store.set(useMegabitsPerSecond, forKey: Keys.useMegabitsPerSecond) }
    }

    @Published var sampleInterval: TimeInterval {
        didSet { store.set(sampleInterval, forKey: Keys.sampleInterval) }
    }

    @Published var healthChecksEnabled: Bool {
        didSet { store.set(healthChecksEnabled, forKey: Keys.healthChecksEnabled) }
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        showDownloadRate = store.object(forKey: Keys.showDownloadRate) as? Bool ?? false
        showUploadRate = store.object(forKey: Keys.showUploadRate) as? Bool ?? false
        useMegabitsPerSecond = store.object(forKey: Keys.useMegabitsPerSecond) as? Bool ?? false
        sampleInterval = store.object(forKey: Keys.sampleInterval) as? TimeInterval ?? 2
        healthChecksEnabled = store.object(forKey: Keys.healthChecksEnabled) as? Bool ?? true
    }

    private enum Keys {
        static let showDownloadRate = "showDownloadRate"
        static let showUploadRate = "showUploadRate"
        static let useMegabitsPerSecond = "useMegabitsPerSecond"
        static let sampleInterval = "sampleInterval"
        static let healthChecksEnabled = "healthChecksEnabled"
    }
}
