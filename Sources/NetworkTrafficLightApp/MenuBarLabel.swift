import NetworkTrafficLightCore
import SwiftUI

struct MenuBarLabel: View {
    let indicator: IndicatorState
    let downloadRate: String?
    let uploadRate: String?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .accessibilityLabel(accessibilityLabel)

            if let downloadRate {
                Text("↓ \(downloadRate)")
                    .monospacedDigit()
            }

            if let uploadRate {
                Text("↑ \(uploadRate)")
                    .monospacedDigit()
            }
        }
    }

    private var color: Color {
        switch indicator {
        case .gray:
            .gray
        case .green:
            .green
        case .yellow:
            .yellow
        case .red:
            .red
        }
    }

    private var accessibilityLabel: String {
        switch indicator {
        case .gray:
            "Network status is starting"
        case .green:
            "Network is healthy"
        case .yellow:
            "Network health is uncertain"
        case .red:
            "Network is unavailable"
        }
    }
}
