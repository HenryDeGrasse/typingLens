# Typing Lens · M4 Skill Graph + Practice Prescription Prototype

Typing Lens is a local-first typing coach.

This repo currently contains a macOS prototype focused on trustworthy, privacy-safer typing diagnostics and the first deterministic coaching layer. The app still uses a listen-only keyboard event tap after explicit macOS approval, but the main product UI now combines a local typing profile with a small skill graph, weakness detection, and an explainable practice prescription plan.

## Milestone progression

- **M1:** trustable capture demo
- **M2:** aggregate diagnostics prototype
- **M3:** local profile engine for rhythm, flow, correction, and reach
- **M4:** deterministic skill graph + weakness model + practice prescription plan

## What changed in M4

M3 established a content-free local profile.

M4 adds a deterministic interpretation layer above that profile:

- a small hand-authored skill graph
- learner-state snapshots for core typing skills
- weakness candidates such as:
  - same-hand sequences
  - reaches
  - accuracy and recovery
  - hand handoffs
  - flow consistency
- a one-primary-weakness recommendation strategy
- a deterministic next-practice session plan with:
  - confirmatory probe
  - drill blocks
  - post-check
  - transfer check

The current M4 slice is still MVP-sized: it explains and prescribes, but it does not yet run a full in-app drill runtime.

## What this prototype does

- shows a pre-permission explainer UI
- requests/guides Input Monitoring approval
- installs a listen-only `CGEventTap` only after permission is granted
- shows clear capture states:
  - needs permission
  - permission denied
  - recording
  - paused
  - secure input blocked
  - tap unavailable
- keeps built-in and manual excluded apps
- builds a local typing profile from:
  - dwell timing
  - flight timing
  - pause distributions
  - burst distributions
  - correction behavior
  - reach / motor friction buckets
- treats common real-world cases more carefully:
  - long thinking pauses are treated as flow events, not rhythm transitions
  - holding down backspace is tracked as a held-delete burst instead of polluting rhythm
  - navigation keys like arrow keys are not mixed into the main typing profile
- builds an M4 learning snapshot with:
  - skill graph nodes and edges
  - learner-state summaries
  - weakness candidates
  - a recommended next practice session plan
- keeps a macOS menu bar extra for quick status/actions
- keeps advanced literal n-gram diagnostics only as a transient, demoted section
- keeps a raw preview only for DEBUG-only local validation

## What this prototype does not do

- no raw typed text persistence
- no raw event-stream persistence
- no persistent literal bigram/trigram storage in the learner model
- no network activity
- no sync/backend/account system
- no full interactive drill runtime yet
- no AI coaching layer yet
- no web UI yet

## Repo structure

```text
apps/mac/               Runnable macOS app package + app bundle metadata
swift/Packages/Core/    Pure shared Swift types, profile models, and learner-model schemas
swift/Packages/Capture/ Permission flow, tap management, normalization, profile engine,
                        skill-graph interpretation, and local summary stores
docs/                   Vision, roadmap, ownership, M4 graph/rule-engine design,
                        and long-term architecture
packages/               Placeholder for future TypeScript/web packages
scripts/                Local build/run helpers
```

## Key docs

- `docs/m4-skill-graph.md` — M4 skill graph, schema, and rule engine
- `docs/architecture.md` — long-term architecture and AI layering plan
- `docs/vision.md` — short product vision
- `docs/roadmap.md` — milestone roadmap
- `docs/ownership.md` — ownership lanes

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
   - a profile overview
   - a weakness model section
   - a recommended next practice section
7. Open a non-excluded app such as TextEdit or Notes.
8. Type a short paragraph, pause a few times to think, use backspace a few times, and once try holding backspace long enough to bulk-delete part of the text.
9. Return to Typing Lens and confirm these update:
   - included keydowns
   - backspace density
   - held delete bursts
   - rhythm cards
   - flow histograms
   - correction section
   - reach section
   - weakness model / recommended practice plan
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
   - see the current primary weakness if one is available
   - open the main app window
   - pause/resume capture
   - exclude the last observed app
18. Optional persistence check:
   - inspect `~/Library/Application Support/ai.gauntlet.typinglens/typing-profile-store.json`
   - inspect `~/Library/Application Support/ai.gauntlet.typinglens/manual-excluded-apps.json`
   - confirm the stores contain summary/profile data and app identifiers only
   - confirm they do **not** contain raw preview text or persisted literal n-gram strings

## Privacy and storage notes

- The product-facing UI is profile-first and learner-model-first.
- The persisted store is a local summary store of counts and histograms.
- The app does **not** write raw typed text to disk.
- The app does **not** write raw event streams to disk.
- The app does **not** persist the debug raw preview.
- The app does **not** persist literal bigram/trigram tables in the M4 learner model.
- The app does **not** send captured data over the network.
- Manual exclusions are stored separately as app identifiers only.
- On launch, the app clears the old M2 aggregate store so literal n-gram persistence does not carry forward into later milestones.

## Current trust model

Typing Lens currently stores:

- local profile summaries (`typing-profile-store.json`)
- local manual app exclusions (`manual-excluded-apps.json`)

Typing Lens currently does **not** store:

- raw typed text
- raw debug preview text
- raw event streams
- persisted literal n-gram diagnostics

## Development caveat

The build helper uses ad-hoc signing for a local demo bundle. After a rebuild, macOS may occasionally treat the app as changed and require you to re-confirm Input Monitoring access.

If permission appears stuck:

1. remove or toggle the app entry in Input Monitoring
2. re-open the built app
3. click **Re-check Access** again
4. if needed, quit and relaunch once

## Current milestone

- **M4:** deterministic skill graph + weakness model + practice prescription prototype
