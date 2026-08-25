# cfbstats 0.0.0.9000 (development version)

First tracked release of the project scaffolding. The repo now carries the full
ingest → clean → link → features → model → report pipeline, its lineage/audit
layer, and the documentation site, all under version control.

## Pipeline & data

- Added **high-school recruiting ratings** as a first-class table
  (`ingest_recruiting()` → `data/recruiting.parquet`, published on the
  `data-latest` release): CFBD `stars`/`rating`/`ranking` per recruit.
  `clean_recruiting()` builds a per-athlete rating table and
  `link_recruiting()` attaches it to the player-season backbone behind a
  **normalized-name guard** — the recruiting `athleteId` is a *separate*
  namespace that collides across different people (Cam Ward's id maps to a
  different recruit, Xavier Ward), so a rating is trusted only when the recruit
  name agrees with the backbone name; wrong-person ratings are nulled and
  flagged by `recruit_matched`. Guarded, honest coverage of drafted players is
  ~60–72% for recent classes; genuinely unranked players (like Cam Ward) are
  absent by design. Guarded by `contract_recruiting()` (`ok_recruiting`), a data
  dictionary (`inst/dict/recruiting.yml`, dict-parity test), and
  `tests/testthat/test-recruiting.R`. Kept off the model path for now (like the
  team display dimension).
  See [decision 0013](https://github.com/ngiangre/cfbstats/blob/main/decisions/0013-recruiting-id-namespace-collision.md).
- Extended the data window from 2010–2025 to **2010–2026**: `ingest_player_stats()`
  and `ingest_roster()` now default to `2010:2026` (and `data-raw/refresh.R` pulls
  through 2026), with the season contracts (`contract_player_stats()`,
  `contract_conference_tiers()`) and dictionaries updated to match. Draft-facing
  bounds moved to 2027 accordingly — `link_drafted()` now defaults to a
  `2010:2027` draft window (the 2010–2026 stats window plus the following spring's
  draft), and `contract_picks()`/`contract_drafted()` widen their year checks. The
  2026 refresh adds preseason rosters and the completed 2026 draft class; 2026
  season stats are not yet available (season not started).
  See [decision 0012](https://github.com/ngiangre/cfbstats/blob/main/decisions/0012-extend-data-window-to-2026.md).
- `targets` pipeline (`_targets.R`) as the single source of truth for the DAG,
  with stage functions in `R/` (`ingest`, `clean`, `link`, `features`, `model`).
  See [decision 0004](https://github.com/ngiangre/cfbstats/blob/main/decisions/0004-adopt-targets-orchestration.md).
- Lineage/audit layer: `audit_step()` emits a per-step record (row/col counts,
  key coverage, schema hash, contract status, git SHA) into the `audit_log`
  target; data dictionaries in `inst/dict/`.
  See [decision 0005](https://github.com/ngiangre/cfbstats/blob/main/decisions/0005-lineage-and-audit-design.md).
- Data contracts (`pointblank`) and unit tests (`testthat`) run in the pipeline.
- Data dictionaries reconciled with the cleaned schema and now guarded by a
  test: `inst/dict/{coaches,roster,picks}.yml` were completed (coaches gains
  `conference`/`games`/`wins`/`losses`, roster gains `jersey`/`home_city`, picks
  documents all 26 pass-through columns), `contract_coaches()`/`contract_picks()`
  assert the added columns, and `tests/testthat/test-dict.R` asserts every
  `inst/dict/*.yml` matches its target's column names and types.
  See [decision 0010](https://github.com/ngiangre/cfbstats/blob/main/decisions/0010-reviewer-skills-and-dict-parity-test.md).
- v1 scope — weight/coaching/transfer change features and the drafted outcome.
  See [decision 0003](https://github.com/ngiangre/cfbstats/blob/main/decisions/0003-expand-v1-scope-weight-coaching-transfers.md).
- The `data-refresh` workflow now creates the `data-latest` release on first run
  (before uploading), so bootstrapping the data asset no longer needs a manual step.
- Roster finalized as a first-class pipeline target (`roster_file` → `raw_roster`
  → `roster`), replacing the empty-roster fallback; `add_roster_weight()` attaches
  the static roster `weight`. Between-season `weight_delta` is dropped as not
  derivable from CFBD `/roster` (weight is static per player: 0 of 64,350
  multi-season players vary). Enforcing the roster contract surfaced a
  data-quality issue the fallback had hidden: `clean_roster()` now coerces a
  placeholder `weight` of `0` to `NA`, and the contract weight range is 100–500 lb.
  See [decision 0009](https://github.com/ngiangre/cfbstats/blob/main/decisions/0009-finalize-roster-drop-weight-delta.md).
- Fixed a silent fan-out and false-positive draft attribution in the
  draft-outcome join: `picks` carries the full NFL draft history (back to 1936)
  and CFBD reuses `collegeAthleteId` across eras, so a modern player's id could
  match an ancient pick — duplicating a player-season and marking it `drafted`
  off a pre-window draft. `link_drafted()` now ignores picks outside the
  plausible draft window (`draft_window`, default `2010:2026`) and collapses the
  outcome to one pick per `playerId`, making the join strictly 1:1 and only ever
  marking `drafted` for an in-window pick. The new `contract_drafted()`
  (`ok_drafted`, fed into the `link_drafted` audit record) and
  `tests/testthat/test-link.R` guard against regressions.
  See [decision 0011](https://github.com/ngiangre/cfbstats/blob/main/decisions/0011-draft-outcome-one-pick-per-player.md).
- Team logos & colors: a `teams` display dimension sourced from CFBD `/teams`
  (`ingest_teams()`/`clean_teams()`, `data/teams.parquet`), joined by school name
  via `link_team_meta()` at the report layer only (kept off the model path).
  `contract_teams()` enforces full team-name coverage of the player-season
  backbone. See [decision 0008](https://github.com/ngiangre/cfbstats/blob/main/decisions/0008-team-logos-dimension.md).

## Documentation site

- `altdoc` + Quarto website built to `docs/` and deployed to GitHub Pages;
  vignettes read the pipeline via `tar_read()`.
  See [decision 0006](https://github.com/ngiangre/cfbstats/blob/main/decisions/0006-quarto-site-architecture-and-viz.md).
- Site renders reuse a committed Quarto freeze cache (`_quarto/_freeze/`) so CI
  is faster and deterministic.
- Reworked the fan-facing Home (`README.md`) and About page for the
  non-technical fan in [VISION.md](https://github.com/ngiangre/cfbstats/blob/main/VISION.md)
  §10: added a "Where to start" fan path (About → Explore → Analysis) on the
  README, translated the About page's scope and methodology into plain football
  language, and tucked the statistical/tooling detail (the two cultures,
  out-of-time validation, decision log, `testthat`/`pointblank`) into a
  collapsible "For the stats-minded" callout so coders still have it.

## Project conventions

- Developed as an R package; `check()` is a conventions gate, not CRAN prep.
  See [decision 0002](https://github.com/ngiangre/cfbstats/blob/main/decisions/0002-rbuildignore-non-package-files.md)
  and [decision 0001](https://github.com/ngiangre/cfbstats/blob/main/decisions/0001-establish-project-vision-and-conventions.md).
- Established the feature-branch → NEWS → squash-merge workflow used for most
  work here, with this changelog linked from the site.
  See [decision 0007](https://github.com/ngiangre/cfbstats/blob/main/decisions/0007-feature-branch-news-merge-workflow.md).
- Set the package author/maintainer.
- Added three invocable `.claude/skills/` skills: `cfbstats` (slimmed to a
  pointer to `AGENTS.md`/`VISION.md`/dictionaries), `fan-experience-improver`
  (edits the fan-facing site toward the non-technical fan audience while
  protecting the technical pages), and `architecture-improver` (keeps the
  pipeline, data model, and conventions legible and auditable, works
  test/contract-first, and checks that graphics/models preserve expected counts
  and subsets).
  See [decision 0010](https://github.com/ngiangre/cfbstats/blob/main/decisions/0010-reviewer-skills-and-dict-parity-test.md).

The full decision log lives in
[`decisions/`](https://github.com/ngiangre/cfbstats/tree/main/decisions).
