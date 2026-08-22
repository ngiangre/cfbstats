# cfbstats — agent guide

Project memory for AI assistants. Full rationale lives in [VISION.md](VISION.md)
and the [decision log](decisions/); read those before substantive changes.

`cfbstats` studies what shapes a college football player's path to the NFL
draft, and how well it can be **forecast** from information available during
their career — pursuing both explanatory (inference) and predictive answers
(Breiman's two cultures).

## Data

CFBD API (`https://api.collegefootballdata.com`); key in `CFBD_API_KEY`.
Ingestion lives in `data-raw/` and writes parquet to `data/`. Years 2010–2025.

| File | Grain | Key / notes |
|------|-------|-------------|
| `data/picks.parquet` | one drafted player | `collegeAthleteId` (int); position, height, weight, pre-draft ranking, hometown |
| `data/player_stats.parquet` | **long**: player-season-stat | `playerId` (string); pivot `category`/`statType`/`stat` |
| `data/coaches.parquet` | one head-coach-season | head coaches only |
| `data/conference_tiers.parquet` | season × conference | tier 3 Power / 2 G5 / 1 FCS-and-below (decision 0003) |

### Gotchas (do not ignore)

- **Player key = athlete id.** `player_stats.playerId`, `roster.id`, and
  `picks.collegeAthleteId` (coerce int→string) are one namespace — join on it,
  not name. ~98–100% of picks from draft year 2013 on carry an id (decision 0003).
- **Stats are long**, not wide — feature building requires pivoting.
- **Watch for silent row loss on joins.** Validate row counts before/after.
- **Coaches are head coaches only** (no coordinators/S&C). Coach *changes*
  between seasons are v1 features derived from `coaches.parquet`.
- **v1 change features** (decision 0003) — weight delta (`/roster`), transfers +
  direction (via the season-aware tier lookup), coaching changes — require
  linking a player's seasons chronologically by athlete id.
- **Conference tiers are season-aware** (Pac-12 collapse, Big East → AAC, WAC
  dropping FBS football); use the lookup, don't hard-code.

## How we work

- **Population/outcome (v1):** outcome = drafted; denominator = players with a
  stat line, in **draft-eligible seasons**.
- **Evaluation:** out-of-time validation — a model never sees data from on/after
  the draft class it predicts. Guard against leakage.
- **Contracts + TDD:** test logic (`testthat`) and data (`pointblank`: expected
  coverage, schema stability, value ranges, no silent join loss); run in the
  pipeline, fail fast. Add/update a contract with any data-touching code.
- **Decision log:** record substantive decisions in `decisions/` (copy
  `TEMPLATE.md`, next number); distill spike-branch findings into an entry.

## Conventions & stack

- R + tidyverse; base pipe `|>` (not `%>%`); `arrow` for parquet I/O and
  lazy/`collect()` pipelines. Comments brief and about *why*. Match scope.
- Developed as an R package (`devtools`: `load_all`/`document`/`test`/`check`);
  reusable logic in `R/` with roxygen. `check()` is a conventions gate, not CRAN
  prep — non-package material is `.Rbuildignore`d (decision 0002). Intended:
  `targets`, parquet/DuckDB as GitHub release assets, Quarto site on Pages.

## Git

Solo repo. `main` always deployable; short-lived `feat/`/`data/`/`model/`
branches; **squash-merge** for a linear history; throwaway `spike/` branches
never merged. Conventional Commits (`type(scope): summary`). Let CI (testthat +
pointblank) pass before merging data/model changes.
