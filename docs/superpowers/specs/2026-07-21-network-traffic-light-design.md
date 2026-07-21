# Network Traffic Light — Design

## Goal

Build a standalone, native macOS menu-bar app that communicates network health
at a glance and can optionally show live download and upload throughput. The
default view is a colour indicator only. The app must be small, local-only, and
have negligible impact on CPU, memory, and network use.

## Scope

- Target macOS 13 or later.
- Run only as a menu-bar application; do not show a Dock icon.
- Sample the primary network interface every two seconds by default.
- Let the user independently enable download and upload rate labels.
- Include a compact popover for current state, interface information, and
  settings.

Out of scope: packet inspection, per-application traffic reporting, bandwidth
tests, history charts, cloud services, telemetry, and persistent logging.

## Options Considered

### 1. Native Swift menu-bar application — selected

Use SwiftUI `MenuBarExtra`, `NWPathMonitor`, SystemConfiguration, and interface
counter APIs. This runs in-process, needs no elevated privileges, and avoids
periodic subprocesses.

### 2. Menu-bar script/plugin

This is quick to prototype, but periodically launching command-line tools and
parsing their output adds avoidable overhead and failure modes.

### 3. Network/system extension

This provides more telemetry than required, needs substantially more
permissions, and is not justified for aggregate traffic rates.

## User Experience

### Menu-bar item

By default, the item is only a filled circular traffic-light indicator:

- Green: the system reports a satisfied network path and the last health probe
  succeeded.
- Yellow: an active network path exists, but the probe has failed, has not yet
  completed, or a path transition is in progress.
- Red: the system reports no usable network path.
- Gray: the application is starting, resuming from sleep, or has no usable
  counter sample yet.

The dot always remains visible. It must not represent throughput: an idle
connection is healthy, and therefore stays green.

The user can enable either or both optional labels:

- Download enabled: `● ↓ 4.2 MB/s`
- Upload enabled: `● ↑ 180 KB/s`
- Both enabled: `● ↓ 4.2 MB/s ↑ 180 KB/s`

Labels use binary units (`KB/s`, `MB/s`, `GB/s`) and update at the sampling
interval. When a rate cannot yet be calculated, the label shows `—` rather
than an incorrect zero.

### Popover and settings

Clicking the menu-bar item opens a small popover showing:

- The current colour/state and a short reason.
- Selected primary interface and its type when available (Wi-Fi or Ethernet).
- Current download and upload rates.
- Toggles: **Show download rate** and **Show upload rate**, both disabled by
  default.
- Sampling interval selector: 1, 2, 5, or 10 seconds; default 2 seconds.
- A **Connection health check** toggle, enabled by default.

No historical rates are retained. Settings are stored locally using
`UserDefaults`.

## Architecture

### App shell

`NetworkTrafficLightApp` owns the menu-bar scene and `AppState`. It sets the
app as an agent application so it has no Dock icon or main window.

### PrimaryInterfaceResolver

Uses SystemConfiguration's global IPv4/IPv6 state to identify the active
primary interface name. It falls back to an eligible interface that is up,
running, non-loopback, and non-point-to-point. Changes in the system network
configuration cause the resolver to select a new interface and reset the rate
baseline.

### TrafficSampler

Every configured interval, reads the selected interface's receive/transmit byte
counters through `getifaddrs` and `if_data`. It retains only the immediately
previous counter sample:

`rate = max(0, currentBytes - previousBytes) / elapsedSeconds`

An exponential moving average (`alpha = 0.5`) provides a stable display without
retaining history. A missing interface, counter reset/rollover, or sleep/wake
reset discards the previous sample and reports an unavailable rate until the
next valid delta.

### PathHealthMonitor

`NWPathMonitor` provides immediate local path availability. When the path is
satisfied and health checks are enabled, a bounded `HEAD` request to
`https://captive.apple.com/hotspot-detect.html` is attempted every 30 seconds.
Any 2xx or 3xx response is a successful probe. The request has a five-second
timeout, does not download a response body, and does not overlap an existing
probe. Disabling health checks leaves the dot green for a satisfied path and
never sends this request.

The monitor must immediately stop probes and sampling on app termination, and
cancel/restart safely across sleep, wake, and interface changes.

### Presentation model

`NetworkStatusViewModel` combines the selected interface, the latest sample,
the path state, health state, and display preferences into a value suitable for
the menu-bar item and popover. UI code never reads counters or performs network
operations directly.

## Performance and Privacy

- One lightweight interface-counter read every two seconds by default.
- One small health request every 30 seconds only when enabled and connected.
- No packet capture, shell processes, elevated privileges, databases, retained
  traffic history, analytics, or telemetry.
- Sampling stops while the Mac is asleep and returns to a fresh baseline after
  wake.
- The app holds constant-sized state: current path state, current interface,
  current and prior counters, and smoothed rates.

## Failure Handling

- If SystemConfiguration cannot identify an interface, use the eligible
  interface fallback and surface the fallback name in the popover.
- If counters are absent or invalid, show an unavailable rate and retain the
  last valid colour state.
- A failed probe produces yellow; repeated failures do not increase request
  frequency.
- A missing/satisfied path transition immediately updates the colour and
  invalidates outdated rate baselines.

## Verification

- Unit-test byte-delta calculation, unit formatting, smoothing, counter-reset
  handling, and display-label combinations.
- Unit-test colour selection for all path/probe combinations.
- Manually verify Wi-Fi, Ethernet, disconnect/reconnect, sleep/wake, and
  switching between interfaces.
- Verify no Dock icon appears, all default labels remain hidden, settings
  persist across relaunch, and disabled health checks issue no probe requests.
- Measure idle CPU/memory with the default two-second interval and confirm that
  sampling produces no network traffic unless the health check is enabled.
