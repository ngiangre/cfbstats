# Plan: stat-phase taxonomy + interpretable player dossier

## Why

A reviewer looked at extracts for Kyle Allen and Cam Ward and raised five points.
Grounding each against the data shows most are **interpretation/extract gaps, not
wrong data**:

| Feedback | Root cause (verified) | Category |
|---|---|---|
| Can't tell offensive vs defensive vs ST TD | Data *does* separate them: Kyle Allen's TDs are stored as `passing/TD`=16, `rushing/TD`=1, each tagged by `category`. An extract that collapses `statType` to a bare "TD" and drops `category` loses this. | presentation |
| No link for undrafted-but-signed | `picks` holds drafted players only; Cam Ward is in it (2025 #1), Kyle Allen is not (undrafted 2018, signed CAR). `link_drafted()` marks him `drafted = FALSE` and stops — no general college→NFL bridge for UDFAs. | enrichment (real gap) |
| No FCS coaches | `coaches` conferences are all FBS (SEC…FBS Independents); CFBD coaches feed is FBS-only, head-coach-only. | coverage limit — surface as explicit caveat |
| Coaches not per player | `coaches` is team-season grain; `link_coaches()` attaches by `(team, season)`, not surfaced per player. | presentation |
| "before double-checking stats" | no provenance shown to reviewer | presentation (provenance block) |

The 9 stat categories partition cleanly into phases:
- **offense**: `passing`, `rushing`, `receiving`
- **defense**: `defensive`, `interceptions` (defenders' picks — note `passing/INT` is the *thrown* INT), plus `fumbles/REC`
- **special teams**: `kicking`, `punting`, `kickReturns`, `puntReturns`
- **ambiguous**: `fumbles` — `FUM`/`LOST` are offense, `REC` is defense → taxonomy must key on `(category, statType)`, not `category` alone.

## Goals

1. **Enrich the database** with (a) a stat-phase taxonomy (metadata; no re-ingest)
   and (b) a general undrafted→NFL bridge, plus explicit coverage flags.
2. **Build an interpretable player extract** — `player_dossier()` — that renders a
   player's career faithfully, grouped by phase with plain-language labels, coach
   context (with FCS caveat), recruiting, draft **or** undrafted-signed NFL
   outcome, and a provenance/caveats block.

Both follow existing conventions: `R/` functions with roxygen, `pointblank`
contracts, `inst/dict/*.yml`, `audit_step()` lineage, tests, a decision-record,
`NEWS.md`, and `air format`.

## Open questions to confirm before implementing

1. **Dossier as function not pipeline target.** A package **function**
   (on-demand, per player), not a bulk `tar` asset — matching how a blog post
   would use it. Bulk dossiers for all players are out of scope. 
2. **Undrafted bridge scope.** Resolve NFL outcome **per player inside
   the dossier** via a name+college+entry-window guard against `nfl_rosters`, with
   an explicit `nfl_match_method`/confidence flag; never fabricate a link.
   Optionally also materialize a population-level `nfl_college_bridge` table later.
   Keep it strictly **outcome-side / off the model input path** (leakage). Start with the per-dossier resolver and defer the bulk bridge table.
3. **Taxonomy home.** Canonical YAML in `inst/dict/stat_taxonomy.yml`,
   an accessor `stat_taxonomy()` returning a tibble, and materialize it as a
   `stat_taxonomy` table in the DuckDB bundle so SQL users get labels too.
4. **Phase assignment for `interceptions` / `fumbles`.** `interceptions` category = defense; `fumbles` split by statType

## Workstream A — stat-phase taxonomy (enrichment metadata)

**New file `inst/dict/stat_taxonomy.yml`** — canonical, hand-authored mapping,
one entry per `(category, statType)` (all 54 pairs), each with:
`category`, `statType`, `phase` (offense/defense/special_teams),
`label` (plain language, e.g. `defensive/TD` → "Defensive touchdown",
`kickReturns/TD` → "Kick-return TD", `passing/INT` → "Interceptions thrown"),
`kind` (scoring / volume / rate — so a dossier can order/format sensibly), and a
`description`. Same YAML shape as existing dicts (`dataset`, `source`, `grain`,
`key`, `description`, `columns`) **plus** a `values:` block carrying the rows.

**New `R/stat_taxonomy.R`:**
- `stat_taxonomy()` — reads the YAML from `system.file("dict", ...)` and returns a
  tibble (`category, statType, phase, label, kind, description`). Cached per call.
- `label_stats(stats)` — left-joins `stat_taxonomy()` onto a long `player_stats`
  slice, attaching `phase`, `label`, `kind`; the reusable "make stats
  interpretable" helper the dossier and any figure will call.

**Contract `contract_stat_taxonomy(player_stats, taxonomy, stop_on_fail = TRUE)`
in `R/contracts.R`** (mirrors `contract_conference_tiers` coverage style):
- taxonomy has required columns, `phase` ∈ {offense, defense, special_teams},
  rows distinct on `(category, statType)`;
- **coverage**: every `(category, statType)` present in `player_stats` has a
  taxonomy row (fail fast when a new stat appears in a refresh) — the analogue of
  the conference-tier coverage guard, so a new stat can't silently go unlabeled.

**Pipeline wiring (`_targets.R`):**
- `tar_target(stat_taxonomy, stat_taxonomy())`
- `tar_target(ok_stat_taxonomy, pointblank::all_passed(contract_stat_taxonomy(player_stats, stat_taxonomy, stop_on_fail = FALSE)$coverage))`
- add `stat_taxonomy = stat_taxonomy` to the `build_duckdb()` table list
- add an `audit_step(stat_taxonomy, "stat_taxonomy", "clean", keys = c("category","statType"), contract_passed = ok_stat_taxonomy)` row.

**Docs:** add a `stat_taxonomy` row to `inst/data-model.md`'s table + dict list.

## Workstream B — undrafted→NFL bridge (enrichment, outcome-side)

**Enabling data change — retain a name in `nfl_rosters`.** `clean_nfl_rosters`
currently drops the player name; a name guard is impossible without it. Add
`player_name` (nflverse `full_name`) to `clean_nfl_rosters`, its dict
(`inst/dict/nfl_rosters.yml`), and `contract_nfl_rosters` (col exists / not-null).
`nfl_rosters` already carries `college` — used as a second guard.
*This requires a data refresh to republish `nfl_rosters.parquet` before merge
(per the AGENTS.md "publish before merge" rule).*

**New `R/link.R` function `resolve_nfl_outcome(subject, picks_nfl, nfl_rosters, nfl_player_stats)`:**
- Input: one player's identity (`playerId`, `player` name, `college`/`team`,
  last college season).
- **Drafted path (reliable):** if the player's `playerId` is in `picks` with a
  match in `picks_nfl` (existing slot bridge, decision 0014), report drafted with
  round/overall and the `gsis_id`-keyed longevity.
- **Undrafted path (guarded):** otherwise attempt a match against `nfl_rosters`
  on `normalize_name(player)` + normalized `college` + plausible entry window
  (rookie season ≈ last college season + 1). Emit `nfl_status` ∈
  {drafted, undrafted-signed, no-NFL-record} and `nfl_match_method` ∈
  {slot, name+college, none} plus a confidence note. **Never** attach an outcome
  on an ambiguous/multiple-candidate match — fall back to "no-NFL-record" and say
  so. Longevity (distinct roster seasons, career games) computed from `gsis_id`
  only when a match is trusted; right-censoring noted for recent classes.
- Reuses the existing `normalize_name()` guard (decision 0013 style).

**Tests (`tests/testthat/test-link.R`):** Kyle-Allen-like fixture (undrafted, name
matches one gsis with matching college/window → undrafted-signed); Cam-Ward-like
(drafted via slot); a name-collision fixture (two candidates → no-NFL-record, not
a false link).

*(Population-level `nfl_college_bridge` table + its own target/contract/dict is a
follow-up, deferred per open question 2.)*

## Workstream C — `player_dossier()` (the interpretable extract)

**New `R/dossier.R`.** Signature mirrors `player_trajectory()` (accepts the tables,
so it works on arrow datasets or tibbles, and a thin convenience wrapper can open
the DuckDB/parquet):

```
player_dossier(id, player_stats, roster, coaches, tiers, picks, picks_nfl,
               recruiting, teams, nfl_rosters, nfl_player_stats, taxonomy = stat_taxonomy())
```

Returns an object of class `cfb_dossier` — a named list of tidy tibbles plus
metadata — with these sections:

1. **identity** — name, position(s), physicals (height/weight from roster),
   hometown, teams & seasons.
2. **stats_by_phase** — long `player_stats` for the id, `label_stats()`-enriched,
   grouped offense / defense / special_teams; each stat spelled out via `label`,
   **never** a bare "TD". One tidy tibble (`season, team, phase, category, label,
   stat`) plus a wide per-season summary for printing.
3. **coaching** — head coach(es) per player-season via `link_coaches` logic;
   midseason changes flagged; **explicit `coach_available = FALSE` ("non-FBS / not
   in CFBD coaches feed")** where the join is empty, rather than a silent `NA`.
4. **recruiting** — name-guarded HS rating (`link_recruiting`), or "unrated" as a
   real category (decision 0013), never imputed.
5. **outcome** — `resolve_nfl_outcome()`: drafted (year/round/overall) **or**
   undrafted-signed with NFL longevity **or** no-NFL-record; `nfl_match_method` and
   censoring noted.
6. **provenance** — sources per section, join methods/keys, coverage flags
   (`coach_available`, `recruit_matched`, `nfl_match_method`), and known gaps, so a
   reviewer can validate instead of guess.

**`print.cfb_dossier()`** — a readable console rendering (section headers, phase
groupings, caveats) — the artifact to hand a reviewer. `as_tibble`/accessors expose
the underlying tidy tables for joins.

**Tests (`tests/testthat/test-dossier.R`):** small multi-table fixtures for a
drafted QB and an undrafted QB; assert (a) TDs are split by phase with labels,
(b) an empty coach join yields `coach_available = FALSE` not `NA`, (c) undrafted
player shows `undrafted-signed`, (d) provenance block lists the flags.

## Cross-cutting

- **Decision record:** copy `decisions/TEMPLATE.md` to the next number; capture the
  taxonomy grain rationale (`(category, statType)` because of `fumbles`), the
  outcome-side/leakage stance of the NFL bridge, and the FCS coach coverage
  caveat. Reference it from `NEWS.md`.
- **`NEWS.md`:** add a user-facing entry linking the new decision (full GitHub URL).
- **`inst/data-model.md`:** add `stat_taxonomy`; note the `nfl_rosters.player_name`
  addition; document the undrafted-outcome resolution as outcome-side.
- **Refresh & publish:** because `nfl_rosters` schema changes, run a refresh-mode
  `tar_make()` and republish `nfl_rosters.{parquet,duckdb}` to `data-latest`
  **before** merging, so a fresh track-mode build finds the new column.
- **Gate:** `devtools::document()` + `devtools::test()` + `devtools::check()` clean;
  `air format .`; let CI (testthat + pointblank) pass on the branch.

## Suggested sequencing

1. Workstream A (taxonomy) end to end — self-contained, no data refresh, immediately
   makes the offense/defense/ST distinction usable.
2. Workstream B enabling change (`nfl_rosters.player_name`) + `resolve_nfl_outcome()`
   + tests; refresh/republish `nfl_rosters`.
3. Workstream C (`player_dossier()` + print method) composing A and B; validate on
   Kyle Allen and Cam Ward.
4. Decision record, NEWS, data-model, docs, format, check; branch + PR.

## Out of scope (v1)

- Sourcing FCS coaches from a non-CFBD feed (documented as a known gap instead).
- Population-wide `nfl_college_bridge` table (per-dossier resolver first).
- Wiring taxonomy/phase or NFL outcomes into the model input path (leakage).
- Bulk dossier generation / a dossier site page (could follow as a vignette later).

## Risks

- **Undrafted name+college matching is collision-prone.** Mitigation: require
  name + college + entry-window agreement, refuse ambiguous matches (fall back to
  "no-NFL-record"), and expose `nfl_match_method` so trust is visible. This risk is
  contained to the dossier/outcome side and kept off the model path.
- **New stat appears on refresh unlabeled.** The coverage contract fails fast, same
  pattern as conference tiers.
- **`nfl_rosters` schema change** must be published before a track-mode build runs,
  or the `nfl_rosters_file` target errors — sequenced above.
