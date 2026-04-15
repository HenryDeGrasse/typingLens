# Long-Term Architecture

## Product direction

Typing Lens should evolve as a **local-first typing coach** built on a structured learner model, not as a raw-key logger and not as an LLM-first coaching shell.

The long-term backbone is:

- **skill graph** for domain structure
- **learner state vector** for current student state
- **tracing/update layer** for how the state changes over time
- **drill-effect model** for intervention quality
- **AI augmentation layer** for explanation, authoring, and later optimization

The guiding rule is:

> Graph is the structure, learner state is the truth, and AI is an augmentation layer.

## System layers

### 1. Native capture layer

Owns:
- macOS permission flow
- input monitoring state
- event tap health
- exclusions
- secure input blocking

Constraints:
- never persist raw text
- never persist raw event streams
- keep any raw preview debug-only and transient

### 2. Normalization layer

Turns native events into privacy-safer descriptors such as:
- key class
- hand pattern
- distance bucket
- row / zone bucket
- correction phase
- burst / pause context

This layer should discard text-like information as early as possible for product-facing storage.

### 3. Profile engine

Builds content-free summaries:
- dwell
- flight
- pauses
- bursts
- correction behavior
- reach / motor friction
- baseline vs recent deltas

This is the M3 foundation and remains the evidence substrate for all later coaching.

### 4. Student model layer

Uses a skill graph plus per-skill state.

For each skill, track dimensions such as:
- control
- automaticity
- consistency
- stability
- uncertainty
- recency
- coverage

This is the first true learner model and should become the product source of truth for coaching decisions.

### 5. Prescription layer

Maps current student state into:
- weakness candidates
- confidence levels
- confirmatory probes
- drill families
- difficulty levels
- near-transfer checks
- later passive transfer tickets

The first version should be deterministic and explainable.

### 6. Practice runtime layer

Owns:
- short probes
- drill blocks
- practice session sequencing
- immediate post-drill checks
- near-transfer checks
- aggregate-only evidence logging
- passive transfer ticket creation

This layer should consume the learner model, not invent its own concept of mastery.

### 7. AI augmentation layer

AI should be layered on top of the structured model, not used as the core source of truth.

Good AI use cases:
- explanation generation from structured state
- drill copy generation
- content authoring support
- curriculum refinement support
- later drill-order optimization and transfer modeling

Bad AI use cases:
- replacing the learner model with opaque chat output
- deciding capture/trust behavior
- inventing hidden runtime state that cannot be evaluated

## Why graph + learner state is the right design

A pure knowledge graph is not enough because it only describes relationships.

A pure mastery vector is not enough because it loses prerequisite and transfer structure.

A pure knowledge tracing model is not enough because typing is a motor-skill domain with overlapping subskills, speed-accuracy tradeoffs, and strong context effects.

The strongest long-term design is a hybrid:

- graph for structure
- vector for current state
- updater for change over time
- effect model for interventions

## Local-first AI architecture

### Current / near-term

Use no AI in the critical runtime coaching loop.

Focus on:
- deterministic rules
- explicit thresholds
- confidence gating
- transfer evaluation
- strong trust surfaces

### Medium-term

Use AI for:
- structured explanation generation
- drill text generation
- coach summaries
- authoring and curriculum maintenance

Use RAG only over structured assets such as:
- skill graph
- learner state
- drill library
- outcome history
- pedagogy rules

### Long-term / SOTA path

Evolve toward:
- graph-aware learner tracing
- uncertainty-aware recommendation
- learned drill effect estimates
- transfer modeling
- maybe on-device adaptive policies

Even then, the persistent data model should remain structured and explainable.

## Evaluation philosophy

If Typing Lens wants to be genuinely state-of-the-art, evaluation must be a first-class system.

### Required eval layers

1. **Signal evals**
   - are the profile metrics stable?
   - do pauses, held delete, exclusions, and secure input behave correctly?

2. **Diagnosis evals**
   - do passive candidates align with confirmatory probes?

3. **Intervention evals**
   - does the prescribed drill improve the targeted skill immediately?

4. **Transfer evals**
   - does the gain show up later in passive typing?

5. **Trust evals**
   - no raw persistence
   - no literal n-gram persistence in the learner model
   - release/debug boundaries are correct

The long-term moat is not “largest model.” It is measurable, trustworthy intervention quality.

## Repository evolution

### Current repo roles

- `apps/mac/` — native UI and runtime wiring
- `swift/Packages/Core/` — pure types, state models, and learner model schemas
- `swift/Packages/Capture/` — capture, normalization, profile aggregation, and rule engines

### Near-future additions

Likely next seams:
- `swift/Packages/Learning/` for student model and prescription logic once it grows beyond Capture
- `swift/Packages/Practice/` for practice runtime and drill generation when needed

Do not create those packages until the code pressure is real.

## Architectural north star

Typing Lens should eventually behave like this:

1. Observe typing locally and safely
2. Update a structured learner model
3. Detect likely weaknesses with confidence
4. Verify them with short targeted probes
5. Prescribe a small deterministic practice session
6. Measure immediate and delayed transfer
7. Use AI only where it improves explanation, authoring, or optimization without weakening trust

That is the path to a strong, local-first, state-of-the-art typing coach.
