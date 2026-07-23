# Probe Quality Indicator Design

Date: 2026-07-23

## Problem

The menu-bar light previously meant “a network path exists and the captive
portal probe succeeded.” On trains and other low-signal areas, macOS often
still reports a satisfied path while the link is too unstable to send an agent
prompt. Idle traffic shows ~0 Mbps on both a healthy desk link and a black
hole, so throughput cannot distinguish them.

## Goal

Green means the connection recently looked stable enough for interactive work.
Idle healthy Wi‑Fi stays green. Degraded mobile links turn yellow or red via
probe latency and a short failure streak.

## Behaviour

Health checks remain the quality signal. When enabled:

| Colour | Meaning |
|--------|---------|
| Green | Last probe succeeded in under 800ms, and neither of the last 2 probes failed |
| Yellow | Probe pending, last success took 800ms–3s, or exactly 1 of the last 2 probes failed |
| Red | No usable path, 2 consecutive probe failures, or last success took ≥3s |
| Gray | App starting / monitor reset |

When health checks are disabled, a satisfied path stays green (path-only mode).

Probes use `HEAD https://captive.apple.com/hotspot-detect.html`, a 5s timeout,
non-overlapping requests, and a 10s interval. Each completion stores
`(succeeded, duration)`; only the last two samples drive the streak.

Throughput labels remain optional and never drive the colour.

## Components

- `PathHealthMonitor` measures probe duration, keeps a 2-sample history, and
  publishes `(ProbePhase, [ProbeSample])`.
- `NetworkStatusReducer` maps path + phase + recent samples + the health-check
  toggle into `IndicatorState` with fixed Practical thresholds.
- Menu-bar and popover copy describe stable / unstable / unreliable connection
  rather than generic “healthy.”

## Non-goals

- Mbps-based colouring
- User-configurable latency thresholds or probe interval UI
- Alternate probe endpoints
