# 0020 — `player_trajectory()` consumes the cleaned schema

- **Status:** Accepted
- **Date:** 2026-08-29

## Context

`player_trajectory()` (`R/link.R`) and the first blog post
(`vignettes/2026-08-27-buechele-allen.qmd`) were written when the published
`data/*.parquet` still carried the **raw** ingest schema: the helper filtered
the college roster on `id` and read NFL roster team from `team`, and the post's
recruiting chunk and team-metadata join used raw recruiting columns
(`athleteId`, `name`, `year`, `committedTo`, `ranking`, `city`,
`stateProvince`) and `teams$school`.

Decision 0018 then made the published parquet the **cleaned** tables — one
identical schema for parquet, DuckDB, and the dictionaries. That renamed the
columns these consumers relied on (`roster.id` → `playerId`, `nfl_rosters.team`
→ `nfl_team`, `teams.school` → `team`, and the recruiting columns to
`playerId` / `recruit_name` / `hs_class` / `national_rank` / `committed_to`,
dropping hometown). The mismatch stayed hidden because the blog post is frozen
(`freeze: true`, decision 0015) and served from its committed
`_quarto/_freeze/` cache — but any re-execution (re-freeze, or a fresh render
without the cache) failed with "column doesn't exist".

## Decision

Align the consumers with the single cleaned schema rather than adapt columns at
the call site:

- `player_trajectory()` now filters roster `playerId` and reads NFL roster
  `nfl_team` (renamed to `team` internally); its roxygen and the
  `tests/testthat/test-link.R` fixtures were updated to the cleaned column
  names.
- The blog post's recruiting chunk uses the cleaned recruiting columns (hometown
  is no longer carried), and its team-metadata join uses `teams$team`. The
  post's committed freeze was regenerated against the fixed code.

Alternative considered and rejected: renaming columns (`playerId` → `id`,
`nfl_team` → `team`) inside the `.qmd` before passing them to the helper. That
would have kept the raw-schema coupling that 0018 removed and left the tested
helper out of step with the data model.

## Hypotheses / expectations

Keeping the helper on the same cleaned schema as every other table means new
blog posts and pipeline code can pass the published parquet straight through
with no per-call renaming, and the `test-link.R` fixtures now double as
documentation of the expected input columns.

## Consequences

- `player_trajectory()` is now coupled to the cleaned schema; a future rename in
  `clean_roster` / `clean_nfl_rosters` must update the helper and its fixtures
  (the dict-parity and link tests will catch it).
- Frozen blog posts remain shielded from data-model churn by their committed
  freeze, but a re-freeze now requires the whole post to run against the current
  cleaned schema — so schema changes should sweep the frozen posts, not just the
  live pipeline.
- Added `data-raw/build-site.R` (sets `CFBSTATS_ROOT`, runs
  `altdoc::render_docs(freeze = TRUE)`) so a local re-freeze reproduces the CI
  `site` build exactly.

## Outcome / what we learned

_Filled in later._
