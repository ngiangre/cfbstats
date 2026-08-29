# 0019 — Stat-phase taxonomy and interpretable player dossier

- **Status:** Accepted
- **Date:** 2026-08-29

## Context

A reviewer given raw extracts for Kyle Allen and Cam Ward raised five points:
(1) offensive, defensive, and special-teams stats weren't separated — you
couldn't tell an offensive TD from a defensive or return TD; (2) there was no
link for a player who went **undrafted yet signed** with an NFL team; (3) no FCS
coaches appeared; (4) coaches weren't attributed per player; and (5) the numbers
were hard to sanity-check.

Grounding each against the data showed most were **interpretation/extract gaps,
not wrong data**:

- The long `player_stats` already tags every stat with a `category` (Kyle
  Allen's TDs are stored as `passing/TD`=16 and `rushing/TD`=1). The nine
  categories partition cleanly into phases; an extract that collapses `statType`
  to a bare "TD" loses this. `fumbles` is the one phase-ambiguous category
  (`FUM`/`LOST` are offense, `REC` is defense).
- `picks` holds drafted players only, so the draft-slot NFL bridge (decision
  0014) can't reach undrafted free agents. `nfl_rosters` had no player-name
  column, so a name-guarded UDFA match was impossible.
- The CFBD `/coaches` feed is FBS head-coaches only; FCS/lower and coordinators
  are absent — a genuine coverage limit, not an error.

## Decision

**Enrich the database and add an interpretable extract**, both faithful to what
we have (absences are labeled, never imputed):

1. **Stat-phase taxonomy** — hand-authored package data
   (`inst/extdata/stat_taxonomy.csv`) mapping each `(category, statType)` to a
   `phase` (offense / defense / special_teams), a plain-language `label`, and a
   `kind` (scoring / volume / rate). Read via `stat_taxonomy()`; applied by
   `label_stats()`. Keyed at `(category, statType)` grain precisely so ambiguous
   categories like `fumbles` are split per statType. `contract_stat_taxonomy()`
   enforces coverage of every pair in `player_stats` (fail fast on a new stat,
   the conference-tier coverage pattern). Materialized into the DuckDB bundle;
   **not** published as a parquet.
2. **General NFL-outcome resolver** — `resolve_nfl_outcome()` answers, per
   player, drafted (reliable draft-slot bridge) **or** undrafted-signed
   (name-guarded match against `nfl_rosters`, disambiguated by college then
   rookie-year window). It **refuses to guess**: an unresolved name collision
   returns `no-NFL-record` rather than a false link. Enabled by adding
   `player_name` to `clean_nfl_rosters` (+ dict + contract). Kept strictly
   outcome-side / off the model input path (leakage).
3. **`player_dossier(id, …)`** — a `cfb_dossier` object (tidy tables + a
   `print()` method) with sections: identity; stats grouped/labeled by phase;
   coaching per player-season with an explicit "not available (non-FBS / not in
   CFBD feed)" where the join is empty; name-guarded recruiting (unrated stays
   unrated); the drafted/undrafted-signed outcome with right-censored longevity;
   and a provenance/caveats block so a reviewer can validate.

Alternatives not taken: a population-wide `nfl_college_bridge` table (deferred —
the per-dossier resolver is enough for v1 and contains the risky matching); a
non-CFBD FCS coach source (documented as a known gap instead); wiring phase or
NFL outcomes into the model path (leakage).

## Hypotheses / expectations

- Handing a reviewer a `player_dossier()` printout — rather than a raw extract —
  resolves the offense/defense/ST, undrafted-signed, FCS-coach, and per-player
  coach confusions in one artifact, because each is now labeled or explicitly
  flagged.
- The name+college+window guard yields few false NFL links; ambiguous cases fall
  back to `no-NFL-record` and are visible via `nfl_match_method`.

## Consequences

- `nfl_rosters` gains a column, so `data/nfl_rosters.{parquet,duckdb}` must be
  refreshed and republished on `data-latest` before a track-mode build runs, or
  the `nfl_rosters_file` target errors.
- New DuckDB table (`stat_taxonomy`) and a new coverage contract added to the
  pipeline/audit log.
- The undrafted match is a heuristic (common names); it is confined to the
  outcome side and exposes its method so trust is legible.

## Outcome / what we learned

Validated on the two review subjects: Kyle Allen resolves to
**undrafted-signed**, 9 NFL roster seasons (right-censored); Cam Ward to
**drafted #1 overall, 2025**, with his 2021 Incarnate Word season correctly
flagged as an FCS coach-coverage gap and his stats split across offense/defense
phases with plain-language labels.
