# Launch at Login — Design

## Goal

Let people optionally start Network Traffic Light when they sign in to macOS.
The setting is disabled by default and must reflect macOS's actual login-item
registration state.

## Design

Use `SMAppService.mainApp` from ServiceManagement, available on macOS 13 and
later. Enabling the popover's **Launch at login** toggle calls
`SMAppService.mainApp.register()`; disabling it calls `unregister()`.

The toggle reads `SMAppService.mainApp.status` every time the popover is
presented. It is on only when the status is `.enabled`. A `.requiresApproval`
or `.notRegistered` status is off. The app does not store a separate
UserDefaults preference for this setting, which avoids claiming that login
launch is enabled when macOS has revoked or disabled it.

If registration or unregistration fails, the app shows a concise message in
the popover and restores the toggle to the state reported by macOS. When macOS
requires approval, the message directs the user to System Settings → General →
Login Items.

## Scope

- Add a disabled-by-default toggle below the existing rate-display settings.
- Add a short status/error message only when launch-at-login needs attention.
- Support macOS 13+ without a helper executable or custom LaunchAgent.
- Add focused state tests around ServiceManagement status mapping.

Out of scope: automatic enablement, a separate helper app, custom launch-agent
files, or managing any login item besides this app.
