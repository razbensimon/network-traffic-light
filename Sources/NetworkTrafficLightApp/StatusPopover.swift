import AppKit
import NetworkTrafficLightCore
import SwiftUI

struct StatusPopover: View {
    @ObservedObject var model: NetworkStatusViewModel
    @ObservedObject var preferences: Preferences
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @ObservedObject var updates: UpdateController

    var body: some View {
        if #available(macOS 26.0, *) {
            popoverContent
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(statusText)
                    .font(.headline)
                Spacer()
                Text(versionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LabeledContent(
                "Download",
                value: model.rate.map { RateFormatter.string(for: $0.downloadBytesPerSecond) } ?? "—"
            )
            LabeledContent(
                "Upload",
                value: model.rate.map { RateFormatter.string(for: $0.uploadBytesPerSecond) } ?? "—"
            )

            Divider()

            Text("Updates")
                .font(.headline)
            Toggle(
                "Automatically check for updates",
                isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.automaticallyChecksForUpdates = $0 }
                )
            )
            Button("Check for Updates…") {
                updates.checkForUpdates()
            }

            Divider()

            Toggle("Show download rate", isOn: $preferences.showDownloadRate)
            Toggle("Show upload rate", isOn: $preferences.showUploadRate)
            Toggle("Use Mbps (Fast.com-style)", isOn: $preferences.useMegabitsPerSecond)
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )
            if let message = launchAtLogin.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Toggle("Connection health check", isOn: $preferences.healthChecksEnabled)
                .onChange(of: preferences.healthChecksEnabled) { _ in
                    model.restartMonitoring()
                }

            Picker("Sampling interval", selection: $preferences.sampleInterval) {
                Text("1 second").tag(TimeInterval(1))
                Text("2 seconds").tag(TimeInterval(2))
                Text("5 seconds").tag(TimeInterval(5))
                Text("10 seconds").tag(TimeInterval(10))
            }
            .onChange(of: preferences.sampleInterval) { _ in
                model.restartMonitoring()
            }

            Divider()

            Button("Quit Network Traffic Light") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 290)
    }

    private var versionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        return "v\(version)"
    }

    private var statusText: String {
        switch model.indicator {
        case .gray:
            "Starting network monitor"
        case .green:
            "Network healthy"
        case .yellow:
            "Network health uncertain"
        case .red:
            "No usable network path"
        }
    }
}
