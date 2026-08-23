# 0012 — Extend the data window to 2026

- **Status:** Accepted
- **Date:** 2026-08-23

## Context

The project was scoped to seasons 2010–2025 (decision 0003), a window hard-coded
as the default in the ingest functions and echoed by the data contracts, the
conference-tier lookup, the draft-outcome window, and the data dictionaries. With
the 2026 draft class complete (April 2026) and 2026 preseason rosters published,
the 2010–2025 ceiling was leaving current data on the table and would drift
further out of date each week.

The window appears in more than one place, so extending it is not a one-line
change: the *stats/roster season* window and the *draft* window are one year
apart by construction (a season leads to the **following** spring's draft), and
several `pointblank` contracts bound `season`/`year`/`draft_year` to keep the
audit honest. Changing only `ingest.R` would leave the contracts rejecting the
newly-pulled 2026 rows.

## Decision

**Extend the season window to 2010–2026 end to end, and move the draft-facing
bounds to 2027 accordingly.**

- Ingest: `ingest_player_stats()` and `ingest_roster()` now default to
  `2010:2026`; `data-raw/refresh.R` pulls through 2026.
- Season contracts: `contract_player_stats()` and `contract_conference_tiers()`
  bound `season` to 2010–2026; the tier lookup (`data-raw/conference_tiers.R`) is
  rebuilt from the refreshed `player_stats`.
- Draft-facing bounds → 2027, since a 2026 season leads to the 2027 draft:
  `link_drafted()` defaults to `draft_window = 2010:2027` (the 2010–2026 stats
  window plus the following spring's draft), and `contract_picks()` /
  `contract_drafted()` widen their `year` / `draft_year` checks to 2027. This
  honors decision 0011's standing note that widening the stats window requires
  widening `draft_window` to match.
- Dictionaries (`inst/dict/{player_stats,roster,conference_tiers}.yml`) updated to
  say 2010–2026.

The refreshed parquet is published to the `data-latest` GitHub release via
`piggyback` (the same path the `data-refresh` job uses), keeping large data out
of git history (decision 0006 / AGENTS.md).

## Hypotheses / expectations

- The pipeline runs clean on the extended window: all contracts pass and the
  audit log shows no new silent row loss. (Confirmed on this refresh — 66 tests
  pass, `tar_make()` green, all `contract_passed = TRUE`.)
- No schema change, so the dict–schema parity test (decision 0010) is unaffected.

## Consequences

- **The 2026 season has not started (refresh run 2026-08-23), so there are no
  2026 `player_stats` rows yet** — only 2026 preseason rosters (~15.5k rows) and
  the completed 2026 draft class (257 picks). Consequently the conference-tier
  lookup and the player-season backbone carry no 2026 rows until a refresh once
  the season is underway. This is expected, not a defect: the window now *admits*
  2026 data as it arrives.
- The stats and draft windows must continue to move together: any future
  extension of the season window requires bumping the draft-facing bounds
  (`draft_window`, `contract_picks`, `contract_drafted`) by the same amount.

## Outcome / what we learned

_Filled in later._
