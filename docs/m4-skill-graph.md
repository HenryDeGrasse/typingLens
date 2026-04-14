# M4 Skill Graph, Schema, and Rule Engine

## Goal

M4 adds a deterministic interpretation layer above the M3 profile engine.

M3 answers: _what does the timing and correction data look like?_  
M4 answers:

1. What weakness category best explains the pattern?
2. Is there enough evidence to trust it?
3. What drill should run next?
4. Did that drill help, and did the effect transfer back to normal typing?

The core design rule is:

> Persist abstract motor skill evidence, not literal text fragments.

## Design shape

Use a hybrid model:

- **skill graph** for structure
- **per-skill learner state** for the student model
- **rule engine** for deterministic weakness detection and prescription
- **practice outcomes** for future drill-effect estimates

This keeps the current product local-first, interpretable, and ready for more advanced future models.

## Graph structure

### Leaf skills

These are the directly observable, coachable motor or process skills.

- `sameHandShortControl`
- `sameHandMediumControl`
- `sameHandLongControl`
- `crossHandHandoff`
- `farReachPrecision`
- `correctionRecovery`
- `burstRestartControl`
- `rhythmConsistency`

### Aggregate skills

These group related leaf skills and become more stable user-facing concepts.

- `handCoordination`
- `reachPrecision`
- `repairEfficiency`
- `flowFluency`
- `rhythmStability`

### Outcome nodes

These are product-level outcomes, not directly trained as first-class drills.

- `sustainableAccuracy`
- `sustainableFluency`
- `transferQuality`

## Edge types

The graph uses a small typed edge set:

- `partOf`
- `prerequisite`
- `positiveTransfer`
- `negativeInterference`
- `observes`

For typing, keep hard prerequisites rare. The system should rely more on soft transfer and support edges than rigid curriculum dependencies.

## M4 weakness taxonomy

### 1. Same-hand sequences

User-facing label: **Same-hand sequences**

Primary evidence:
- same-hand flight slower than matched cross-hand flight
- same-hand p90 inflation
- optional support from correction burden

Drill family:
- `sameHandLadders`

### 2. Reaches

User-facing label: **Reaches**

Primary evidence:
- far-reach flight slower than near-reach flight
- optional support from correction burden

Drill family:
- `reachAndReturn`

### 3. Accuracy and recovery

User-facing label: **Accuracy and recovery**

Primary evidence:
- elevated backspace density versus baseline
- elevated pre-correction hesitation
- elevated recovery latency
- held-delete bursts can reinforce diagnosis

Drill family:
- `accuracyReset`

### 4. Hand handoffs

User-facing label: **Hand handoffs**

Primary evidence:
- cross-hand transitions are not getting the expected alternation advantage
- optional support from p90 inflation

Drill family:
- `alternationRails`

### 5. Flow consistency

User-facing label: **Flow consistency**

Primary evidence:
- burst collapse versus baseline
- inflated pause burden
- elevated overall flight tail or IQR

Drill family:
- `meteredFlow`

For the first M4 slice, the first four are primary user-facing weaknesses. Flow consistency can exist but should remain lower priority because it is more confounded by cognition and task context.

## Confidence model

### Candidate only from passive data

Passive typing should produce a **candidate**, not an immediate diagnosis.

### Confidence levels

- **low**: one threshold crossing with minimum sample
- **medium**: repeated threshold crossings or one threshold crossing with a strong baseline comparison
- **high**: repeated threshold crossings with stronger evidence support

### Cold-start rule

Do not strongly emphasize named weaknesses until:

- the baseline is at least building, and
- there is enough evidence in the relevant bucket

Before that, the product should present softer language like “monitoring” or “building evidence.”

## Severity model

Use simple threshold offsets over matched-control ratios.

- **mild**: threshold met but only slightly above trigger
- **moderate**: clearly above trigger
- **strong**: substantially above trigger or supported by multiple signals

## Prescription strategy

### One primary weakness at a time

MVP rule:

- pick one primary weakness
- assign one drill family
- build one short session plan

### Priority order

1. `accuracyRecovery`
2. `reachPrecision`
3. `sameHandSequences`
4. `crossHandHandoff`
5. `flowConsistency`

The reason is simple: heavy correction burden contaminates speed and timing interpretation, so it should usually be handled before motor-speed drills.

### Drill families

- `sameHandLadders`
- `reachAndReturn`
- `alternationRails`
- `accuracyReset`
- `meteredFlow`
- `mixedTransfer`

### Session skeleton

Every recommended session should follow the same simple shape:

1. confirmatory probe
2. 2–4 short drill blocks based on severity
3. post-drill check
4. later transfer check in passive typing

This creates the clean attribution loop:

> detect → verify → drill → re-check → monitor transfer

## Long-term persistence shape

The long-term durable entities should be:

### `SkillNode`
- id
- name
- family
- level
- active dimensions
- graph version

### `SkillEdge`
- from skill id
- to skill id
- edge type
- weight
- confidence
- graph version

### `StudentSkillState`
Per skill, persist:
- control
- automaticity
- consistency
- stability
- uncertainty
- effective sample count
- recency
- trend
- model version

### `ObservationBucket`
Privacy-safe evidence bucket, for example:
- passive vs drill source
- dwell p50/p90
- flight p50/p90
- pause rate
- burst metrics
- correction metrics
- sample count

### `ObservationSkillMap`
Maps profile metrics and opportunity classes into skill updates.

### `DrillSkillMap`
Maps drill families to the skills they train or assess.

### `PracticeOutcome`
Stores:
- targeted weakness
- drill family
- difficulty level
- immediate probe change
- later transfer result
- outcome timestamp

## MVP implementation guidance

The first M4 slice should not try to ship the full long-term schema at once. It should:

- ship a small hand-authored skill graph
- derive learner state from M3 profile summaries
- detect a small number of weakness categories deterministically
- generate a deterministic practice session plan
- keep all storage local and abstract

That gives Typing Lens a trustworthy M4 while leaving room for a richer future tracing model.
