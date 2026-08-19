# CLAUDE.md

Project guidance for Claude Code working in this repository.

## What this project is

`cfbstats` studies what shapes a college football player's path to the NFL
draft — and how well that path can be **forecast** from information available
during their career. See [VISION.md](VISION.md) for the full vision, scope, data
model, and modeling philosophy. Read it before making substantive changes.

Guiding frame: Breiman (2001), *Statistical Modeling: The Two Cultures* — we
pursue **both** explanatory (inference) and predictive (algorithmic) answers,
reported side by side.

## Data

Sourced from the CFBD API (`https://api.collegefootballdata.com`); the API key
lives in the `CFBD_API_KEY` environment variable. Ingestion currently lives in
`data-raw/DATASET.R` and writes parquet files to `data/`.

| File | Grain | Notes |
|------|-------|-------|
| `data/picks.parquet` | one drafted player | key `collegeAthleteId` (int); has position, height, weight, pre-draft rankings, hometown |
| `data/player_stats.parquet` | **long**: one row per player-season-stat | key `playerId` (string); columns `category`/`statType`/`stat` must be pivoted |
| `data/coaches.parquet` | one head-coach-season | head coaches only — no coordinators/position/S&C coaches |

Years covered: 2010–2025.

### Known data gotchas (do not ignore)

- **Player linkage is unsolved.** `picks.collegeAthleteId` (int) does not match
  `player_stats.playerId` (string); existing code joins on **name**, which is
  fragile. A reliable player key is a prerequisite for modeling.
- **Coaches are head coaches only.** Assistant/coordinator/S&C coaching is a
  future, separately-sourced sub-project (Wikipedia/Wikidata), not in the CFBD
  data.
- **Stats are long, not wide.** Feature building requires pivoting.
- **Watch for silent row loss on joins.** Validate row counts before/after.

## How we work

- **Population/outcome (v1):** outcome = drafted; denominator = players with a
  stat line, restricted to **draft-eligible seasons**.
- **Evaluation:** headline metric is **out-of-time validation** — never let a
  model see data from on/after the draft class it predicts. Guard against
  leakage.
- **Data contracts + TDD:** test both logic (`testthat`) and data
  (`pointblank`-style expectations: expected years/players/coaches present,
  schema stability, value ranges, no silent join loss). Contracts should run in
  the pipeline and fail fast.
- **Decision log:** record substantive decisions, hypotheses, and
  what worked/didn't in [`decisions/`](decisions/) (ADR-style, numbered/dated;
  copy `decisions/TEMPLATE.md`). Distill spike-branch findings into an entry so
  knowledge survives the branch.

## Intended stack

Developed as an R package using the `devtools` workflow
(`load_all`/`document`/`test`/`check`): reusable logic lives in `R/` with
`roxygen2` documentation, which is surfaced on the Quarto site (pkgdown-style
reference or `altdoc`) so code docs and analysis live together. `check()` is a
**conventions/standards gate, not CRAN prep** — non-package material
(`VISION.md`, `decisions/`, `.claude/`, `data/`, `data-raw/`, site outputs) is
`.Rbuildignore`d; keep it updated as the repo grows (see decision 0002).
`targets` for orchestration; DuckDB / partitioned parquet published as GitHub
**release assets** (accessed in CI via `piggyback` / `gh release download`);
`orbital` for in-database ML; a Quarto website on GitHub Pages built and
data-refreshed by GitHub Actions; possibly a `querychat` app on Posit Connect
Cloud.

## Git workflow

Solo repo (one coder). Conventions favor a clean, disciplined history over
review handoffs.

- `main` is always deployable; Actions build from it.
- Do substantive work on short-lived **feature branches** off `main`
  (`feat/…`, `data/…`, `model/…`).
- Open a **PR** to let CI run `testthat` tests and `pointblank` data contracts;
  it's a self-check/CI gate, not a review handoff. Let CI pass before merging
  anything data- or model-touching; trivial changes can merge directly.
- **Squash-merge** so `main` keeps one clean commit per feature and a linear,
  bisectable history.
- Use **throwaway `spike/…` branches** for experiments ("let's just try it") —
  never merged; distill findings into the decision log.
- Commit messages follow **Conventional Commits** (`type(scope): summary`;
  types `feat`/`fix`/`data`/`model`/`docs`/`refactor`/`test`/`ci`/`chore`,
  scopes like `pipeline`/`data`/`model`/`site`).
- CI: merge to `main` → build/deploy the Quarto site; a separate scheduled
  workflow refreshes CFBD data and publishes release assets.

## Coding conventions

- R with the tidyverse; use the base R pipe `|>` (not `%>%`).
- Prefer `arrow` for parquet I/O and lazy/`collect()` pipelines.
- Keep comments brief and about *why*, not *what*; put pipeline comments on the
  line above the code.
- Match changes to scope; don't refactor or add features beyond the task.
- When adding data-touching code, add or update the corresponding data contract.
