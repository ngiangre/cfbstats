# 0011 — Collapse the draft outcome to one pick per player

- **Status:** Accepted
- **Date:** 2026-08-23

## Context

`link_drafted()` attaches the draft outcome to the player-season backbone by
left-joining `picks` on the string `playerId` (the athlete-id namespace,
decision 0003). An architecture review of the audit log surfaced a silent
row delta: `ps_tier` → `ps_draft` added rows on a join that should never add
any.

Two facts about the source combine to cause it:

1. `data/picks.parquet` carries the **full NFL draft history back to 1936**, not
   just the 2010–2025 stats window (`contract_picks()` already bounds `year` to
   1936–2026 for this reason).
2. CFBD **reuses `collegeAthleteId` across eras**, so a handful of ids map to two
   picks decades apart (e.g. id `3915189` → both "Royce Smith" (1972) and
   "Roquan Smith" (2018); `2162574` → "Clay Matthews" 1978 & 2009).

`link_drafted()` built its lookup with `distinct(playerId, year, round,
overall)`, so a colliding id produced two lookup rows and the left join fanned
out — silently duplicating a player-season and attributing it to the wrong draft
event. Today 8 ids collide and only 1 intersects the 2010–2025 backbone (a +2
row delta), but this is a silent, data-dependent corruption of the outcome that
would grow and shift on every refresh (AGENTS.md "watch for silent row loss on
joins"; architecture-improver principle 2).

## Decision

Collapse the draft-outcome lookup to **one pick per `playerId`** before the
join, so `link_drafted()` is strictly 1:1 on `playerId` and adds no rows. When
an id maps to more than one pick we keep the pick **inside the 2010–2025 stats
window**, then the **most recent** — the pick that actually corresponds to the
player in our backbone.

Alternatives not chosen: (a) leaving the fan-out and de-duplicating downstream —
rejected, it lets a corrupt outcome propagate and defeats the audit guarantee;
(b) name-based disambiguation of colliding ids — deferred as a possible future
QA cross-check (decision 0003 already plans to retire name matching to QA), not
needed for the volume seen.

The join is now guarded by `contract_drafted()` (asserts no row inflation,
`drafted` a complete logical, `draft_year` in-window), wired into `_targets.R`
as `ok_drafted` and fed into the `link_drafted` audit record, plus `testthat`
coverage (`tests/testthat/test-link.R`) for the no-fan-out and
colliding-id-resolution behavior.

## Hypotheses / expectations

- The draft outcome is now exactly one row per player-season; the `ps_tier` →
  `ps_draft` audit delta is zero and stays zero across refreshes.
- `contract_drafted()` fails fast if a future feed change reintroduces fan-out,
  rather than the corruption being discovered at analysis time.

## Consequences

- For a colliding id, the historical (pre-2010) pick is dropped from the
  outcome; this is intended, since those picks are not the player in our
  window. If a future analysis needs full draft history it must go back to
  `picks` directly, not through the player-season outcome.
- No schema change — columns are unchanged, so the dictionaries and the
  dict–schema parity test (decision 0010) are unaffected.

## Outcome / what we learned

_Filled in later._
