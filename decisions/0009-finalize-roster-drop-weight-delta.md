# 0009 — Finalize roster ingestion; drop between-season weight_delta

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

Decision 0003 scoped a v1 `weight_delta` change feature sourced from CFBD
`/roster`, and left roster ingestion as a TODO: the pipeline read roster through
a defensive `read_roster_if_present()` helper that fell back to an empty roster
(so `weight_delta` degraded to `NA`) rather than a first-class `targets` file
target like every other table.

Two facts have since changed the picture:

1. **Roster is already ingested and published.** `ingest_roster()` /
   `clean_roster()` exist, `data-raw/refresh.R` writes `data/roster.parquet`, and
   it ships on the `data-latest` release. The pipeline was already reading it
   (305,543 rows), and `add_roster_weight()` attaches a static `weight` to
   `model_table` at ~81% coverage.
2. **`weight_delta` is not derivable from `/roster`.** CFBD reports a single
   weight per player, repeated across every season. Verified: of **64,350**
   multi-season players with a listed weight, **0** show more than one distinct
   weight. A between-season delta simply is not in this data.

## Decision

- **Promote roster to a first-class target.** Replace `read_roster_if_present()`
  with `roster_file` (`format = "file"`) → `raw_roster <- read_parquet(...)`,
  matching picks/player_stats/coaches/teams. Remove the empty-roster fallback and
  the stale "not yet ingested" scaffolding.
- **Abandon between-season `weight_delta`.** Keep the static `weight` attached by
  `add_roster_weight()`; do not synthesize a season-to-season delta from a source
  that has no variation. This narrows the decision 0003 change-feature set to
  transfers (+ direction) and coaching changes.

Alternatives not chosen: keeping the conditional reader (the file now reliably
exists and is published, so the fallback only hid a real missing-data error); a
*career-span* weight change (draft weight in `picks` vs. college roster weight)
— a derivable but different feature, deferred unless a modeling need arises.

## Hypotheses / expectations

- Treating roster like the other file targets makes a missing/failed data pull
  fail fast (as it should) instead of silently degrading features to `NA`.
- Documenting `weight_delta` as not-derivable prevents re-litigating it and
  keeps the feature set honest about what the source supports.

## Consequences

- A fresh checkout without `data/roster.parquet` now errors at `roster_file`
  (by design) rather than proceeding with an empty roster; CI pulls it from the
  `data-latest` release, so this matches the other tables.
- `weight` remains ~81% covered on the model table (not all player-seasons
  appear on a roster; ~83% within the roster itself); models must tolerate the
  residual `NA`s or impute.
- Enforcing the roster contract (rather than the old graceful fallback) means a
  malformed weight now fails `ok_roster` in the pipeline instead of passing
  silently — this is how the `weight == 0` placeholder was caught.

## Outcome / what we learned

Roster is now a first-class file target: `read_roster_if_present()` and its
empty-roster fallback are removed, and `roster_file` (`format = "file"`) →
`raw_roster` → `roster` matches picks/player_stats/coaches/teams. `tar_validate()`
is clean and the roster targets build (305,543 rows).

Promoting the contract from advisory to enforced surfaced a data-quality issue
the empty-roster fallback had hidden: 27 of 305,543 rows failed the weight range
check — 26 rows with `weight == 0` (an impossible value, `/roster`'s
missing-data placeholder) and 1 row at `455` lb (a genuine extreme lineman, just
over the old 450 ceiling). Resolution: `clean_roster()` now coerces `weight == 0`
to `NA`, and the contract range widened to 100–500 lb (`na_pass = TRUE`).
`ok_roster` now passes. Static `weight` coverage is ~83% within the roster
(~81% once joined onto the draft-eligible model table); the residual `NA`s are
genuine missing physicals, not placeholders. `weight_delta` stays dropped as
decided.
