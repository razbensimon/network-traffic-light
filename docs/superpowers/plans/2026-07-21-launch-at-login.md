# Launch at Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a disabled-by-default native macOS launch-at-login toggle and release it as v1.0.1.

**Architecture:** Keep ServiceManagement isolated in an app-target controller. A small pure core state type maps macOS registration results into UI state so it can be tested by the existing self-contained check executable.

**Tech Stack:** Swift 6, ServiceManagement `SMAppService`, SwiftUI, Swift Package Manager.

## Global Constraints

- Support macOS 13+ without a helper app, LaunchAgent plist, or stored login-item preference.
- Read actual `SMAppService.mainApp.status` when the popover opens.
- Registration is opt-in and disabled for a new installation.
- Registration failures must leave the toggle aligned with the system state and show an actionable message.
- Do not create commits until the user requests publishing; this release request authorizes one personal-account commit and push.

---

## Planned Files

```text
Sources/NetworkTrafficLightCore/LaunchAtLoginState.swift  # Pure UI-state mapping
Sources/NetworkTrafficLightApp/LaunchAtLoginController.swift # ServiceManagement adapter
Sources/NetworkTrafficLightApp/NetworkStatusViewModel.swift  # Owns login controller
Sources/NetworkTrafficLightApp/StatusItemController.swift    # Refreshes state before popover
Sources/NetworkTrafficLightApp/StatusPopover.swift           # Toggle and error message
Checks/NetworkTrafficLightChecks/main.swift                   # State assertions
Resources/Info.plist                                          # Version 1.0.1
README.md                                                     # Login-item documentation
```

### Task 1: Add testable launch-at-login state

**Files:**
- Create: `Sources/NetworkTrafficLightCore/LaunchAtLoginState.swift`
- Modify: `Checks/NetworkTrafficLightChecks/main.swift`

**Interfaces:**
- Produces `LaunchAtLoginState` with `isEnabled` and `guidance`.
- `LaunchAtLoginController` consumes this type.

- [ ] **Step 1: Write the failing behavior checks**

```swift
expectEqual(LaunchAtLoginState.enabled.isEnabled, true, "enabled login item")
expectEqual(LaunchAtLoginState.notRegistered.isEnabled, false, "disabled login item")
expectEqual(
    LaunchAtLoginState.requiresApproval.guidance,
    "Enable Network Traffic Light in System Settings → General → Login Items.",
    "approval guidance"
)
```

- [ ] **Step 2: Run the checks and verify failure**

Run: `swift run NetworkTrafficLightChecks`

Expected: FAIL because `LaunchAtLoginState` is undefined.

- [ ] **Step 3: Add the minimal state implementation**

```swift
public enum LaunchAtLoginState: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval

    public var isEnabled: Bool { self == .enabled }

    public var guidance: String? {
        self == .requiresApproval
            ? "Enable Network Traffic Light in System Settings → General → Login Items."
            : nil
    }
}
```

- [ ] **Step 4: Run the checks and verify success**

Run: `swift run NetworkTrafficLightChecks`

Expected: PASS.

### Task 2: Bridge ServiceManagement and surface the setting

**Files:**
- Create: `Sources/NetworkTrafficLightApp/LaunchAtLoginController.swift`
- Modify: `Sources/NetworkTrafficLightApp/NetworkStatusViewModel.swift`
- Modify: `Sources/NetworkTrafficLightApp/StatusItemController.swift`
- Modify: `Sources/NetworkTrafficLightApp/StatusPopover.swift`

**Interfaces:**
- Consumes `SMAppService.mainApp.status` and `LaunchAtLoginState`.
- Produces `LaunchAtLoginController.isEnabled`, `message`, `refresh()`, and `setEnabled(_:)`.

- [ ] **Step 1: Implement the ServiceManagement controller**

```swift
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var state = LaunchAtLoginState.notRegistered
    @Published private(set) var message: String?

    var isEnabled: Bool { state.isEnabled }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            state = .enabled
            message = nil
        case .requiresApproval:
            state = .requiresApproval
            message = state.guidance
        default:
            state = .notRegistered
            message = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            message = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Own the controller in `NetworkStatusViewModel`**

```swift
let launchAtLogin = LaunchAtLoginController()
```

- [ ] **Step 3: Refresh it immediately before showing the popover**

```swift
model.launchAtLogin.refresh()
popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
```

- [ ] **Step 4: Add the toggle and guidance**

```swift
Toggle(
    "Launch at login",
    isOn: Binding(
        get: { launchAtLogin.isEnabled },
        set: { launchAtLogin.setEnabled($0) }
    )
)
if let message = launchAtLogin.message {
    Text(message).font(.caption)
}
```

- [ ] **Step 5: Build and manually validate**

Run: `swift build`

Expected: `Build complete!`.

Manually enable the toggle, verify the app appears in Login Items, disable it,
and verify it is removed.

### Task 3: Publish v1.0.1

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `README.md`

- [ ] **Step 1: Set `CFBundleShortVersionString` to `1.0.1`**
- [ ] **Step 2: Document that launch-at-login is opt-in and managed by macOS Login Items**
- [ ] **Step 3: Verify and package**

Run:

```bash
swift run NetworkTrafficLightChecks
swift build -c release
./Scripts/build-app.sh
```

Expected: checks pass and the app bundle contains version `1.0.1`.

- [ ] **Step 4: Commit, push, and create the personal GitHub release**

Use the personal `razbensimon` GitHub CLI account, restore `raz-drift` after
publishing, create tag `v1.0.1`, and attach a ZIP of the Apple Silicon app.

## Plan Self-Review

- **Spec coverage:** Native registration, opt-in default, live system status,
  error guidance, test coverage, versioning, and release packaging are all
  covered.
- **Placeholder scan:** No implementation or release requirement is undefined.
- **Type consistency:** `LaunchAtLoginState` is defined before the controller
  and all UI consumers.
