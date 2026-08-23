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
| `data/roster.parquet` | one player-season on a roster | `id`→`playerId` (string) + `season`; physicals/position/hometown. Weight is **static** per player (decision 0009) |
| `data/teams.parquet` | one team (program) | join by school **name** (`team`); logos/colors, DISPLAY only (decision 0008) |
| `data/conference_tiers.parquet` | season × conference | tier 3 Power / 2 G5 / 1 FCS-and-below (decision 0003) |

### Gotchas (do not ignore)

- **`data/` is gitignored — NO parquet is tracked in git.** Do **not** `git add`
  or commit `data/*.parquet` (a `git status` won't even show it). The raw tables
  ship as assets on the **`data-latest` GitHub release**: `data-raw/refresh.R`
  writes `data/*.parquet` locally, `piggyback::pb_upload(..., tag="data-latest")`
  publishes them (the `data-refresh.yaml` job), and `site.yaml` does
  `piggyback::pb_download(tag="data-latest")` on a fresh checkout. Adding a new
  table means: add its `ingest_*()` to `data-raw/refresh.R`, then run the refresh
  (or `pb_upload` the single file) to publish it **before** merging — otherwise a
  fresh CI/site build can't find it and the `*_file` target errors.
- **Player key = athlete id.** `player_stats.playerId`, `roster.id`, and
  `picks.collegeAthleteId` (coerce int→string) are one namespace — join on it,
  not name. ~98–100% of picks from draft year 2013 on carry an id (decision 0003).
- **Stats are long**, not wide — feature building requires pivoting.
- **Watch for silent row loss on joins.** Validate row counts before/after.
- **Coaches are head coaches only** (no coordinators/S&C). Coach *changes*
  between seasons are v1 features derived from `coaches.parquet`.
- **v1 change features** (decision 0003) — transfers + direction (via the
  season-aware tier lookup) and coaching changes — require linking a player's
  seasons chronologically by athlete id. **No between-season `weight_delta`:**
  CFBD `/roster` reports a *static* weight per player (0 of 64,350 multi-season
  players vary), so only the static `weight` is attached (decision 0009).
  `clean_roster` coerces a placeholder `weight` of `0` to `NA`; the roster
  contract enforces a 100–500 lb range (decision 0009).
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
  Decisions 0004–0006 cover `targets`, the lineage/audit layer, and the site.

## Pipeline, lineage & site (in place)

- **`_targets.R`** is the pipeline and single source of truth for the DAG
  (decision 0004). Stages: **ingest → clean → link → features → model →
  report**. Functions live in `R/` by stage: `ingest.R`, `clean.R`, `link.R`,
  `features.R`, `model.R` (placeholder), `contracts.R`, `audit.R`, `viz.R`.
  Ingest targets read committed `data/*.parquet` so the graph runs offline; a
  fresh CFBD pull uses the `ingest_*()` functions (`data-raw/refresh.R`).
- **Lineage/audit** (decision 0005): `audit_step()` emits a uniform per-step
  record (row/col counts, rows dropped, key coverage, NA cells, schema hash,
  contract pass/fail, git SHA) → the `audit_log` target. Data dictionaries in
  `inst/dict/*.yml`. Known audit signals: `build_player_season` collapses the
  long stats (~1.2M → ~144k rows); `link_coaches` inflates rows where a school
  had >1 head coach in a season (intentional many-to-many).
- **Site** (decision 0006): **`altdoc` owns the site** (`quarto_website`),
  configured in `altdoc/quarto_website.yml`, built to `docs/` via
  `altdoc::render_docs()`. Home = `README.md`; content pages are **vignettes**
  (`vignettes/{about,data,pipeline,analysis,explore}.qmd`, surfaced via
  `$ALTDOC_VIGNETTE_BLOCK`); Reference is auto-generated per-function from
  `man/*.Rd` (`$ALTDOC_MAN_BLOCK`). Vignettes read the pipeline via `tar_read()`
  and set the knit wd to the project root from the `CFBSTATS_ROOT` env var
  (altdoc renders in a temp dir); they use `library(cfbstats)` and
  `system.file("dict", ...)`, so the package must be installed to render. Viz is
  hybrid: R htmlwidgets default (`plotly`/`ggiraph`/`reactable`), OJS later.
  `vignettes/` is `.Rbuildignore`d (they need the pipeline/data, not CRAN).
- **CI** (`.github/workflows/`): `check.yaml` (R CMD check + testthat + contract
  fixtures), `site.yaml` (pull data release asset → `tar_make()` → render →
  Pages), `data-refresh.yaml` (scheduled ingest → publish parquet via
  `piggyback`). Site/refresh need `CFBD_API_KEY` and Pages enabled.
- **Roster is a first-class target** (`roster_file` → `raw_roster` → `roster`,
  decision 0009): `data/roster.parquet` is ingested by `refresh.R`, published on
  the `data-latest` release, and read like the other tables. `add_roster_weight`
  attaches the static `weight` (~81% coverage). No `weight_delta` (see above).

## Conventions & stack

- R + tidyverse; base pipe `|>` (not `%>%`); `arrow` for parquet I/O and
  lazy/`collect()` pipelines. Comments brief and about *why*. Match scope.
- Developed as an R package (`devtools`: `load_all`/`document`/`test`/`check`);
  reusable logic in `R/` with roxygen. `check()` is a conventions gate, not CRAN
  prep — non-package material is `.Rbuildignore`d (decision 0002). `check()` is
  currently clean (0 errors/warnings/notes).

## Git

Solo repo. `main` always deployable; short-lived `feat/`/`data/`/`model/`
branches; **squash-merge** for a linear history; throwaway `spike/` branches
never merged. Conventional Commits (`type(scope): summary`). Let CI (testthat +
pointblank) pass before merging data/model changes. **Before merging a feature
branch into `main`, update `NEWS.md`** with the user-facing changes (linking any
relevant decision record via full GitHub URL) — an empty changelog entry is a
smell, and R CMD check flags a NEWS with no entries (decision 0007).

**Formatting is enforced by CI** (`format-check.yaml` runs `air format . --check`)
but is **not** part of `devtools::check()`. Run `air format .` before pushing, or
enable the tracked pre-commit hook once per clone: `git config core.hooksPath
.githooks` (it mirrors the CI check; skips gracefully if `air` isn't on PATH).
