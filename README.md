# Network Traffic Light

A local-only macOS menu-bar indicator for connection health and optional live
upload/download rates.

<img src="docs/images/app-icon.png" width="160" alt="Network Traffic Light app icon">

## Screenshots

![Menu-bar network indicator](docs/images/menu-bar-indicator.png)

![Network Traffic Light status popover](docs/images/status-popover.png)

## Requirements

- macOS 13+
- Xcode Command Line Tools with Swift 6

## Run during development

```bash
swift run NetworkTrafficLight
```

## Build an app bundle

```bash
./Scripts/build-app.sh
open build/NetworkTrafficLight.app
```

## How the indicator works

The menu-bar dot describes connection health:

- Green: macOS reports a usable network path and the latest health check
  succeeded.
- Yellow: a path exists, but the health check is pending or failed.
- Red: macOS reports no usable network path.
- Gray: the app is starting or resetting its sample baseline.

By default, only the dot is visible. Enable **Show download rate** and/or
**Show upload rate** from the popover to add live labels. Enable
**Use Mbps (Fast.com-style)** to show decimal megabits per second (`Mbps` or
`Gbps`) instead of the default byte-based rate.

### Launch at login

Enable **Launch at login** in the popover to register the installed app with
macOS Login Items. The setting is disabled by default and reflects macOS's
actual registration state. If approval is required, enable it in System
Settings → General → Login Items.

### Updates

The installed app checks the update feed once a day by default. Toggle
**Automatically check for updates** off to stop background checks, or use
**Check for Updates…** to check immediately. Every downloaded update archive
is verified with the app's embedded EdDSA public key before installation;
updates are never installed silently.

Update checks fetch the public `appcast.xml` from this repository's GitHub raw
URL. If an update is available, the selected archive is downloaded from its
GitHub Release only after you approve it.

#### Release process

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `Resources/Info.plist`. The build number must always increase.
2. Run the checks:

   ```bash
   swift run NetworkTrafficLightChecks
   ```

3. Prepare the signed release archive and update entry:

```bash
./Scripts/prepare-update-release.sh
```

4. Commit and push the code and version changes, excluding `appcast.xml`.
5. Create GitHub Release tag `v<version>` and upload the ZIP reported by the
   script.
6. Commit and push the generated `appcast.xml`.

Uploading the ZIP before publishing `appcast.xml` ensures that an installed app
never receives an update link before the archive is available.

### What the rates mean

The rates are aggregate traffic on the active primary network interface:

- **Download** is bytes received per second.
- **Upload** is bytes sent per second.
- The figures include every app and background service using that interface.

The app reads macOS's existing byte counters every two seconds by default,
calculates the change divided by elapsed time, then applies 50% smoothing to
avoid a flickering display. It does not capture packets, inspect their content,
or retain traffic history. The first sample after startup, wake, or an
interface change establishes a fresh baseline, so a rate may temporarily show
as unavailable.

### Network requests and privacy

Traffic measurement itself makes no network request. It only reads local
operating-system counters and requires neither administrator privileges nor
telemetry.

When **Connection health check** is enabled (the default), the app sends an
HTTPS `HEAD` request to:

`https://captive.apple.com/hotspot-detect.html`

It runs once when a usable path is detected and then at most once every
30 seconds, with a five-second timeout. `HEAD` requests ask for headers only,
not a response body. Disabling the setting stops these app-originated health
requests.

The code intentionally targets only that Apple endpoint. It does not disable
standard URL-session redirects or system proxy configuration, however, so a
network or proxy can relay or redirect the request.

## Verification

Run the self-contained checks with:

```bash
swift run NetworkTrafficLightChecks
```

The project uses these checks because the installed Command Line Tools do not
include XCTest or Swift Testing. The checks cover rate calculation and
formatting, primary-interface selection, traffic-light states, and sampler
baseline behavior.

- The default menu-bar item is a colour dot only.
- Upload and download labels can be enabled independently and persist.
- The app samples only the primary interface’s aggregate byte counters.
- Rates reset after an interface change until a valid delta exists.
- A health probe has a five-second timeout, runs no more than once per
  30 seconds when enabled, and does not run when disabled.
