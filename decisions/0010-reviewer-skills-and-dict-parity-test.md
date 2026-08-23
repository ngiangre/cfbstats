# 0010 — Reviewer skills and a dictionary–schema parity test

- **Status:** Accepted
- **Date:** 2026-08-23

## Context

The repo's surface area has grown to span two audiences (VISION §10): a
non-technical football fan navigating the site, and the coder/analyst
maintaining the pipeline. Two recurring needs emerged:

1. A repeatable way to invoke *focused* review — one lens for whether the site
   stays accessible and navigable to a fan, another for whether the architecture
   (functions, `targets` DAG, data model, conventions) stays legible and
   auditable with no loose ends.
2. A guard against a specific silent-drift risk: the data dictionaries
   (`inst/dict/*.yml`, decision 0005) are hand-maintained and can fall out of
   sync with the actual cleaned schema when a `clean_*()` function or the CFBD
   feed changes — exactly the "discover a schema problem too late" failure
   VISION §8 warns against.

## Decision

**Three invocable skills under `.claude/skills/`:**

- `cfbstats` — slimmed to a thin pointer to `AGENTS.md`, `VISION.md`,
  `inst/dict/*.yml`, and `decisions/` (it had drifted and largely duplicated
  project memory).
- `fan-experience-improver` — actively edits the fan-facing surfaces
  (`README.md`, the `about`/`analysis`/`explore` vignettes, fan-facing nav)
  toward the VISION §10 fan, while *protecting* the technical pages
  (`data`/`pipeline`/Reference).
- `architecture-improver` — keeps functions, the `targets` pipeline, the data
  model, and conventions legible and auditable; works test/contract-first; and
  verifies graphics/models preserve expected row counts and data subsets.

Shared reference and process material is not restated in the skills — they point
to `AGENTS.md`. The two reviewer skills carry a symmetric ownership line for the
Explore vignette: `fan-experience-improver` owns the fan-facing framing/copy,
`architecture-improver` owns chart correctness and count/subset preservation.

**A dictionary–schema parity test** (`tests/testthat/test-dict.R`): for each
`inst/dict/*.yml`, reconstruct the cleaned target from its committed raw parquet
via the corresponding `clean_*()` function and assert the dictionary documents
exactly that column *name* set and matching *types*. The test skips when the raw
data is unavailable (e.g. R CMD check without the `data-latest` release). This
landed alongside completing the dictionaries (coaches gains
`conference`/`games`/`wins`/`losses`; roster gains `jersey`/`home_city`; picks
documents all 26 pass-through columns) and tightening the contracts
(`contract_coaches()` asserts `wins`; `contract_picks()` asserts the documented
pass-through columns).

Alternative considered: reading a built `_targets` store in the test. Rejected —
it would couple the test to a materialized store and to run location;
reconstructing from raw via `clean_*()` is deterministic and store-independent.

## Hypotheses / expectations

- The skills let us summon the right lens on demand and keep both audiences
  served without one degrading the other.
- The parity test catches dictionary drift the moment a `clean_*()` function or
  the feed changes, rather than at analysis time.

## Consequences

- The skills follow the `.claude/skills/` convention; they are guidance, not
  enforced by CI.
- The parity test **skips under R CMD check** (data is not shipped in the
  package), so parity is enforced locally and in any data-bearing CI job, not in
  `check.yaml`. Follow-on option: wire it into the data-bearing site/refresh job,
  or extend contracts to assert types directly.

## Outcome / what we learned

_Filled in later._
