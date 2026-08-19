# 0001 — Establish project vision and working conventions

- **Status:** Accepted
- **Date:** 2026-08-18

## Context

Starting the `cfbstats` project: a study of what shapes (and predicts) a college
football player being drafted into the NFL. An interview surfaced the motivating
questions (does coaching matter? which career variables matter? per-season odds
of going pro by position?) and the available data (CFBD `/draft/picks`,
`/stats/player/season`, `/coaches`). We needed to fix an initial scope, an
analytical philosophy, and the tooling/process conventions before building.

## Decision

Adopt the vision in [VISION.md](../VISION.md). Key commitments:

- **Philosophy:** Breiman's two cultures — pursue explanatory *and* predictive
  answers side by side.
- **v1 scope:** head-coach / program-level coaching only; outcome = drafted;
  denominator = players with a stat line, restricted to draft-eligible seasons.
  Assistant/coordinator/S&C coaching and alternative "pro" definitions are later
  sub-projects.
- **Evaluation:** out-of-time validation is the headline metric; no leakage from
  the predicted draft class or later.
- **Infra:** developed as an R package via the `devtools`/`roxygen2` workflow
  (docs surfaced on the Quarto site); `targets` orchestration; DuckDB/parquet as
  GitHub release assets; `orbital` for in-DB ML; Quarto site on GitHub Pages via
  Actions; possible `querychat` app on Posit Connect Cloud.
- **Quality:** `testthat` for logic + `pointblank`-style data contracts run in
  the pipeline; this decision log as the learning harness.
- **Git:** solo development; short-lived feature branches, squash-merge to a
  clean linear `main`, `spike/…` branches for experiments, Conventional Commits;
  CI on merge to `main` plus a scheduled data refresh.
- **Audience:** non-technical football fans and R/football-stats coders.

Collaboration model: one coder; the collaborator contributes domain questions
and ideas rather than code.

## Hypotheses / expectations

- Program/head-coach signal (SP+ offense/defense, SRS, wins) will carry *some*
  information about draft outcomes even before assistant-coach data exists.
- Out-of-time validation will give materially more honest performance estimates
  than random cross-validation for this forecasting task.
- Fixing conventions up front (package workflow, data contracts, decision log)
  will prevent the failure mode of discovering missing/misrepresented
  variables, players, coaches, or years late in the analysis.

## Consequences

- Several known data problems must be resolved before modeling — chiefly the
  unsolved player-linkage key (`picks.collegeAthleteId` int vs.
  `player_stats.playerId` string; current name-matching is fragile), the
  long-format stats needing a pivot, and head-coaches-only coaching coverage.
- The package + contracts + log discipline adds up-front overhead in exchange
  for reproducibility and durable knowledge.

## Outcome / what we learned

_Filled in later._
