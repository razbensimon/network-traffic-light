import AppKit
import Combine
import NetworkTrafficLightCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject, ObservableObject {
    private let model: NetworkStatusViewModel
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private let popover = NSPopover()
    private var modelChangeSubscription: AnyCancellable?

    init(model: NetworkStatusViewModel) {
        self.model = model
        super.init()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: StatusPopover(
                model: model,
                preferences: model.preferences,
                launchAtLogin: model.launchAtLogin,
                updates: model.updates
            )
        )

        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover)

        modelChangeSubscription = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateButton()
            }
        }
        updateButton()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.launchAtLogin.refresh()
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateButton() {
        let title = NSMutableAttributedString(
            string: "●",
            attributes: [
                .foregroundColor: indicatorColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )

        if let downloadRate = model.displayedDownloadRate {
            title.append(rateTitle(" ↓ \(downloadRate)"))
        }

        if let uploadRate = model.displayedUploadRate {
            title.append(rateTitle(" ↑ \(uploadRate)"))
        }

        statusItem.button?.attributedTitle = title
        statusItem.button?.toolTip = accessibilityLabel
    }

    private func rateTitle(_ value: String) -> NSAttributedString {
        NSAttributedString(
            string: value,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            ]
        )
    }

    private var indicatorColor: NSColor {
        switch model.indicator {
        case .gray:
            .systemGray
        case .green:
            .systemGreen
        case .yellow:
            .systemYellow
        case .red:
            .systemRed
        }
    }

    private var accessibilityLabel: String {
        switch model.indicator {
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
