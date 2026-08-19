---
name: cfbstats
description: >-
  Work with the cfbstats college-football data and analysis in this repository.
  Use when loading, cleaning, joining, or modeling the CFBD draft-picks,
  player-season-stats, or coaches datasets, building features toward predicting
  NFL draft outcomes, or extending the targets pipeline / Quarto site. Covers
  the data schemas, known linkage gotchas, and project conventions.
---

# cfbstats

Analysis of what predicts (and explains) a college football player being
drafted into the NFL. Read [VISION.md](../../../VISION.md) and
[CLAUDE.md](../../../CLAUDE.md) for full context before substantive work.

## Data files (parquet in `data/`)

- `picks.parquet` — one row per drafted player. Key `collegeAthleteId` (int).
  Includes `position`, `height`, `weight`, `preDraftRanking`, `round`, `pick`,
  `overall`, and `hometownInfo_*`.
- `player_stats.parquet` — **long** format: one row per player-season-*stat*
  (`category`, `statType`, `stat`). Key `playerId` (string). Pivot before
  modeling.
- `coaches.parquet` — one row per **head**-coach-season, with `seasons_srs`,
  `seasons_spOffense`, `seasons_spDefense`, wins, etc. No assistant coaches.

Ingestion: `data-raw/DATASET.R`, using the CFBD API with key `CFBD_API_KEY`.
Years 2010–2025.

## Loading

```r
library(arrow)
library(dplyr)

picks   <- read_parquet("data/picks.parquet")
coaches <- read_parquet("data/coaches.parquet")

# player_stats is large and long — read lazily, filter/pivot, then collect
stats <- read_parquet("data/player_stats.parquet", as_data_frame = FALSE)
```

## Critical gotchas

1. **No clean player key across tables.** `picks.collegeAthleteId` (int) does
   not join to `player_stats.playerId` (string). Name-matching is fragile —
   solving a reliable linkage is a prerequisite for modeling, not an
   afterthought.
2. **Head coaches only.** Coordinator/position/S&C coaching is not in the data;
   it is a future, separately-sourced sub-project.
3. **Long stats.** Pivot `category`/`statType`/`stat` into position-relevant
   columns for features.
4. **Silent join loss.** Always check row counts before/after joins.

## Analysis conventions

- Model **draft-eligible seasons only**; outcome = drafted; per-position
  probabilities.
- **Out-of-time validation** is the headline metric — no leakage from the
  predicted draft class or later.
- Report **both** an explanatory answer (effect + uncertainty, e.g. Bayesian
  hierarchical / mixed models) and a predictive one (algorithmic models with
  LIME/Shapley interpretation).
- Add/maintain **data contracts** (`pointblank`) alongside `testthat` logic
  tests; run them in the `targets` pipeline so bad assumptions fail fast.
- Log substantive decisions and hypotheses so knowledge accumulates.

## Code style

- Tidyverse; base R pipe `|>`. `arrow` for parquet. Brief, *why*-focused
  comments. Scope changes tightly.
