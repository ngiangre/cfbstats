# 0008 — Team logos as a name-joined display dimension

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

We want to show team logos (and colors) in the site/report. "Team" appears in
every table as a school-name string (`player_stats.team`, `roster.team`,
`picks.collegeTeam`, `coaches.seasons_school`), and the existing coach link
already joins on that name. CFBD `/teams` returns logos, colors, mascot,
abbreviation and conference per program — the natural source.

Before committing, we checked name coverage: all 325 distinct `player_season`
teams match a `/teams` `school` exactly (100%). The wrinkle is that `/teams`
contains 57 duplicate school names — a real program plus a phantom row with
`NA` classification and no logos — which a naive name join would fan out.

## Decision

Add `teams` as a first-class **display dimension**, sourced from `/teams` and
joined by **school name** (parity with the coach join; no new key plumbing).

- `ingest_teams()` flattens the multi-resolution `logos` array to `logo_light` /
  `logo_dark` so the persisted parquet stays flat (as picks/coaches do).
- `clean_teams()` **dedupes to one row per school**, preferring the row with a
  real `classification` then a logo, dropping the phantom.
- `contract_teams()` enforces **coverage** (every `player_season` team resolves
  to a row) and dimension integrity (distinct `team`, non-null key). Logo
  *presence* is deliberately not a hard check.
- `link_team_meta()` attaches logos/colors at the **report/viz layer only** —
  never on the model path, so URLs cannot leak into features.

Alternatives not chosen: joining on a numeric team id (more robust to name
drift, but `player_stats` has no team id, so it would need backfilling — deferred
to v2 if name mismatches appear); restricting to FBS (would drop drafted FCS
players and fail coverage).

## Hypotheses / expectations

- The name join stays 100%-covered as new seasons land; the coverage contract
  will fail fast if a future team name doesn't resolve.
- Keeping logos out of `model_table` preserves the features-vs-display split and
  keeps the model path leakage-free.

## Consequences

- ~10 small programs (e.g. Allen, Barton, Erskine) carry no logo URL and render
  with a placeholder.
- The dimension's `conference` is team-level (current), not season-aware; use
  `conference_tiers` for season logic, not this table.
- If name collisions ever appear across *distinct* real programs, we revisit the
  id-join alternative.

## Outcome / what we learned

_Filled in later._
