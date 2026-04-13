# Typing Lens · M2 Aggregate Diagnostics Prototype

Typing Lens is a local-first typing coach.

This repo currently contains a small macOS prototype focused on trustable, privacy-safer typing diagnostics. The app still uses a listen-only keyboard event tap after explicit macOS approval, but the main product UI now emphasizes aggregate metrics instead of raw captured text.

## What changed from the first MVP

The first milestone proved that Typing Lens could responsibly observe keyboard activity after Input Monitoring approval.

This milestone upgrades that raw/debug capture demo into an **aggregate-first prototype**:

- raw preview is no longer the main UI
- the main app surface emphasizes counts, backspace density, and n-grams
- a small exclusion policy ignores some obviously sensitive or misleading apps
- aggregate metrics can persist locally between launches
- any raw preview remains debug-only, transient, and in memory only

## What this prototype does

- shows a pre-permission explainer UI
- requests/guides Input Monitoring approval
- installs a listen-only `CGEventTap` only after permission is granted
- shows clearer capture states:
  - needs permission
  - permission denied
  - recording
  - paused
  - tap unavailable
- shows privacy-safer aggregate metrics:
  - total observed keydowns
  - total backspaces
  - backspace density
  - top bigrams
  - top trigrams
  - simple average latency for bigrams/trigrams
  - last included event time
  - last aggregate update time
- supports pause/resume
- supports reset/clear
- ignores events from a small hardcoded denylist of apps such as Terminal, iTerm, some password managers, and some remote desktop / VM apps
- lets you add and remove manual app exclusions by bundle ID or from the last observed app
- keeps a demoted debug-only raw preview in RAM only
- optionally persists **aggregate metrics only** to a local JSON file

## What this prototype does not do

- no raw typed text persistence
- no raw event-stream persistence
- no network activity
- no sync/backend/account system
- no coaching, prescription, or practice generation yet
- no web UI yet

## Repo structure

```text
apps/mac/               Runnable macOS app package + app bundle metadata
swift/Packages/Core/    Small pure shared Swift types and state models
swift/Packages/Capture/ Permission flow, tap management, normalization, exclusions,
                        aggregate metrics, and local aggregate store
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

1. clean the local Swift package build artifacts for a reliable local rebuild
2. build the Swift package at `apps/mac/`
3. bundle it into `apps/mac/build/TypingLens.app`
4. ad-hoc sign the bundle
5. open the app

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
   - capture = `recording`
   - tap = installed/enabled
7. Open a non-excluded app such as TextEdit or Notes.
8. Type a short sentence and use backspace a few times.
9. Return to Typing Lens and confirm these update:
   - observed keydowns
   - backspaces
   - backspace density
   - top bigrams
   - top trigrams
   - last included event time
   - last aggregate update time
10. Open Terminal and type a few keys.
11. Return to Typing Lens and confirm:
    - total observed keydowns did **not** increase from those Terminal keystrokes
    - excluded event count increased
12. Use the **Excluded Apps** section to:
    - add the last observed app to manual exclusions, or
    - enter a bundle ID manually
13. Type in that manually excluded app and confirm its keystrokes do **not** increase the main aggregate metrics.
14. Click **Pause Capture** and verify typing in TextEdit or Notes no longer changes aggregates.
15. Click **Resume Capture** and verify aggregates start moving again.
16. Click **Reset Aggregates + Debug State** and verify aggregates/debug state are cleared.
17. Optional persistence check:
    - inspect `~/Library/Application Support/ai.gauntlet.typinglens/aggregate-metrics.json`
    - confirm it contains aggregate counts / n-gram dictionaries only
    - confirm it does **not** contain the raw debug preview or full typed text

## Privacy and storage notes

- The product-facing UI is aggregate-first.
- A raw debug preview still exists only for local development validation.
- That debug preview stays in memory only.
- The app does **not** write raw typed text to disk.
- The app does **not** write raw event streams to disk.
- The app does **not** send captured data over the network.
- The local JSON store is aggregate-only and meant to keep this prototype small.

## Current exclusions

The app currently ignores a first-pass hardcoded set of bundle IDs including:

- Terminal
- iTerm
- 1Password
- Bitwarden
- LastPass
- Microsoft Remote Desktop
- Parallels Desktop
- VMware Fusion
- TeamViewer
- AnyDesk

This list is intentionally small and incomplete. It is only an MVP trust/safety step.

You can also add your own exclusions locally from the app UI. Manual exclusions are stored separately from the aggregate metrics and contain app identifiers only, not captured text.

## Development caveat

The build helper uses ad-hoc signing for a local demo bundle. After a rebuild, macOS may occasionally treat the app as changed and require you to re-confirm Input Monitoring access.

If permission appears stuck:

1. remove or toggle the app entry in Input Monitoring
2. re-open the built app
3. click **Re-check Access** again
4. if needed, quit and relaunch once

## Current milestone

- **M2:** aggregate diagnostics prototype

See `docs/vision.md`, `docs/ownership.md`, and `docs/roadmap.md` for the intended longer-term direction.
