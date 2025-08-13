# PulsePrompt

## Background execution strategy (iPhone)
- VO2 timing is wall-clock based and advanced by HR events (bluetooth-central background mode).
- Foreground UI uses a 1s Timer purely for display.
- HealthKit live workout sessions are watchOS-only; we do not rely on HK to keep timing on iPhone.

## Spotify control
- Foreground: App Remote preferred; Web API fallback.
- Background: Web API only (wrapped in a background task).

## Configuration
- Add Spotify credentials and playlist IDs via `.env` or `Config.plist`.
- Required Info.plist background modes: `bluetooth-central`, `audio`.

## VO2 implementation
- Interval state: `phase`, `start`, `duration` with exact boundary checks.
- Idempotent playlist switching (one switch per interval).
- Durations from `VO2Config` for easy tuning.

## Troubleshooting
- If playlists don’t switch in background: ensure HR session is active during VO2; verify Spotify access token; check device activation path.


