# Typing Lens · M3 Local Profile Engine

Typing Lens is a local-first typing coach.

This repo currently contains a small macOS prototype focused on trustworthy, privacy-safer typing diagnostics. The app still uses a listen-only keyboard event tap after explicit macOS approval, but the main product UI now focuses on a local typing profile instead of persisted literal n-grams or raw text.

## What changed from M2

M2 proved that Typing Lens could capture aggregate-first typing diagnostics with exclusions and trustable local behavior.

M3 upgrades that into a **local profile engine**:

- the main UI now emphasizes **rhythm, flow, correction, and reach**
- the app captures both key-down and key-up so it can estimate **flight** and **dwell** timing
- it persists **content-free daily profile summaries** instead of persisted literal bigram/trigram tables
- bigrams and trigrams are demoted into **transient advanced diagnostics only**
- the app surfaces **baseline-building** vs **baseline-ready** states
- it surfaces **secure input blocked** when macOS says secure event input is active

## What this prototype does

- shows a pre-permission explainer UI
- requests/guides Input Monitoring approval
- installs a listen-only `CGEventTap` only after permission is granted
- shows clearer capture states:
  - needs permission
  - permission denied
  - recording
  - paused
  - secure input blocked
  - tap unavailable
- keeps built-in and manual excluded apps
- builds a local typing profile using:
  - flight timing summaries
  - dwell timing summaries
  - pause distributions
  - burst distributions
  - correction burst summaries
  - same-hand vs cross-hand timing
  - approximate reach-distance timing buckets
- shows a profile-first UI with:
  - overview
  - rhythm
  - flow
  - accuracy
  - reach
  - what changed
  - trust + tap health
- keeps a macOS menu bar extra for quick status/actions
- keeps advanced literal n-gram diagnostics only as a transient, demoted section
- keeps a raw preview only for debug validation in DEBUG builds

## What this prototype does not do

- no raw typed text persistence
- no raw event-stream persistence
- no persistent literal bigram/trigram storage in the main M3 profile
- no network activity
- no sync/backend/account system
- no coaching or practice generation yet
- no web UI yet

## Repo structure

```text
apps/mac/               Runnable macOS app package + app bundle metadata
swift/Packages/Core/    Small pure shared Swift types and profile/dashboard state models
swift/Packages/Capture/ Permission flow, tap management, normalization, exclusions,
                        profile aggregation, and local summary stores
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
   - trust panel shows local profile storage paths
7. Open a non-excluded app such as TextEdit or Notes.
8. Type a short paragraph, pause a few times, and use backspace a few times.
9. Return to Typing Lens and confirm these update:
   - included keydowns
   - backspace density
   - sessions / burst length
   - rhythm cards (flight / dwell)
   - flow histograms (pause / burst)
   - correction section
   - reach section
   - last included event time
10. Open Terminal and type a few keys.
11. Return to Typing Lens and confirm:
   - profile counts did **not** increase from those Terminal keystrokes
   - excluded event count increased
12. Use the **Excluded Apps** section to:
   - add the last observed app to manual exclusions, or
   - enter a bundle ID manually
13. Type in that manually excluded app and confirm its keystrokes do **not** increase the main profile metrics.
14. Click **Pause Capture** and verify typing in TextEdit or Notes no longer changes the profile.
15. Click **Resume Capture** and verify the profile starts moving again.
16. Click **Reset Profile + Diagnostics** and verify profile summaries, transient diagnostics, and debug state are cleared.
17. Open the Typing Lens icon in the macOS menu bar and confirm you can:
   - see capture status at a glance
   - open the main app window
   - pause/resume capture
   - exclude the last observed app
18. Optional persistence check:
   - inspect `~/Library/Application Support/ai.gauntlet.typinglens/typing-profile-store.json`
   - confirm it contains profile summaries / histograms only
   - confirm it does **not** contain raw preview text or literal n-gram strings from typing

## Privacy and storage notes

- The product-facing UI is profile-first and content-free.
- The persisted M3 store is a local summary store of counts and histograms.
- The app does **not** write raw typed text to disk.
- The app does **not** write raw event streams to disk.
- The app does **not** persist the debug raw preview.
- The app does **not** persist literal bigram/trigram tables in the main M3 profile store.
- The app does **not** send captured data over the network.
- Manual exclusions are stored separately as app identifiers only.
- On launch, the app clears the old M2 aggregate store so literal n-gram persistence does not carry forward into M3.

## Current trust model

Typing Lens currently stores:

- local profile summaries (`typing-profile-store.json`)
- local manual app exclusions (`manual-excluded-apps.json`)

Typing Lens currently does **not** store:

- raw typed text
- raw debug preview text
- raw event streams
- persisted literal n-gram diagnostics

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

You can also add your own exclusions locally from the app UI. Manual exclusions contain app identifiers only, not captured text.

## Development caveat

The build helper uses ad-hoc signing for a local demo bundle. After a rebuild, macOS may occasionally treat the app as changed and require you to re-confirm Input Monitoring access.

If permission appears stuck:

1. remove or toggle the app entry in Input Monitoring
2. re-open the built app
3. click **Re-check Access** again
4. if needed, quit and relaunch once

## Current milestone

- **M3:** local profile engine + baseline UI

See `docs/vision.md`, `docs/ownership.md`, and `docs/roadmap.md` for the intended longer-term direction.
