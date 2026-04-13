# Typing Lens · M1 Trustable Capture Demo

Typing Lens is a local-first typing coach.

This repo currently contains only the first milestone: a super-bare macOS MVP that proves the app can responsibly observe keyboard activity after explicit user approval.

## What this MVP does

- shows a pre-permission explainer UI
- requests/guides Input Monitoring approval
- displays permission state: `unknown`, `granted`, or `denied`
- installs a listen-only `CGEventTap` only after permission is granted
- shows live counters for:
  - total keydown events
  - total backspaces
- shows tap health:
  - installed or not
  - enabled or not
  - last event timestamp
- supports pause/resume
- supports clearing the in-memory debug buffer and counters
- keeps a rolling debug-only preview of recent captured keys/events **in memory only**

## What this MVP does not do

- no disk persistence of captured text
- no network activity
- no analytics/aggregation store
- no profile, scoring, coaching, or practice loop yet
- no web app/packages yet

## Repo structure

```text
apps/mac/               Runnable macOS app package + app bundle metadata
swift/Packages/Core/    Small pure shared Swift types and state models
swift/Packages/Capture/ Permission flow, event tap, pause/resume, tap health, in-memory buffer
packages/               Placeholder for future TypeScript/web packages
docs/                   Vision, ownership lanes, and roadmap
scripts/                Local build/run helpers
```

## Requirements

- macOS 13+
- Xcode Command Line Tools or Xcode with Swift available on `PATH`

## Build and run

From the repo root:

```bash
./scripts/run-mac-app.sh
```

That script will:

1. build the Swift package at `apps/mac/`
2. bundle it into `apps/mac/build/TypingLens.app`
3. ad-hoc sign the bundle
4. open the app

If you only want to build:

```bash
./scripts/build-mac-app.sh
```

## Manual verification steps

1. Run `./scripts/run-mac-app.sh`.
2. In the app, click **Request Access / Open Settings**.
3. In macOS, go to **System Settings → Privacy & Security → Input Monitoring**.
4. Enable **Typing Lens** if it appears.
   - If it does not appear, click `+` and add `apps/mac/build/TypingLens.app` manually.
5. Return to the app and click **Re-check Access**.
6. Confirm the UI shows:
   - permission = `granted`
   - tap = `installed`
   - capture = `live`
7. Put another app in front, type a few keys, then come back to Typing Lens.
8. Confirm these change live/in-session:
   - total keydown events
   - total backspaces
   - last event timestamp
   - debug-only in-memory preview
   - recent captured events list
9. Click **Pause Capture** and verify typing no longer changes counters.
10. Click **Resume Capture** and verify counts start moving again.
11. Click **Clear Debug Buffer + Counters** and verify preview/counters reset.

## Important privacy limitations

- The debug preview contains raw captured characters for this milestone.
- That preview is intentionally kept in RAM only.
- The app writes no captured text to disk.
- The app sends no captured text over the network.
- The app does not log captured text to console output.

## Development caveat

The build helper uses ad-hoc signing for a local demo bundle. After a rebuild, macOS may occasionally treat the app as changed and require you to re-confirm Input Monitoring access.

If permission appears stuck:

1. remove or toggle the app entry in Input Monitoring
2. re-open the built app
3. click **Re-check Access** again
4. if needed, quit and relaunch once

## Current milestone

- **M1:** trustable capture demo

See `docs/vision.md`, `docs/ownership.md`, and `docs/roadmap.md` for the intended longer-term direction.
