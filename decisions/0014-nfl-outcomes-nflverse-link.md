# 0014 — NFL outcomes via nflverse: draft-slot link, career-length definition, grain

- **Status:** Accepted
- **Date:** 2026-08-25

## Context

The dataset stops at the draft: `picks.parquet` tells us *who* was drafted but
nothing about what happened next. A recurring fan question — for drafted college
players, what do they do in the NFL, and *how long do they last?* — needs a
post-draft outcome source. `nflverse` (`nflreadr`) is the standard open NFL data
stack and covers our window well (play-by-play/stats from 1999, rosters/draft
further back), so it fits the 2010–2026 window (decision 0012).

The hard part is the join. CFBD `picks` carries an `nflAthleteId`, but a spike
showed it is **CFBD's own namespace, not ESPN's**: 0 / 4,350 of the 2010+ picks'
`nflAthleteId` match nflverse `espn_id` (`load_ff_playerids()`). Name-only
matching recovers ~79% and is collision-prone (the exact hazard of decision
0013). We need a trustworthy bridge into nflverse's `gsis_id` / `pfr_player_id`.

## Decision

**Add `nflreadr` as a dependency** and ingest NFL outcomes for drafted players,
linked by **draft slot**, not by athlete id or name.

- **Link method — draft slot.** Join CFBD `picks` to
  `nflreadr::load_draft_picks()` on `(year = season, round, overall = pick)`.
  The spike matched **4,350 / 4,350 rows, 99.7%** with a `pfr_player_id`; the
  handful of name mismatches are all suffix/nickname formatting (Will Anderson
  Jr. ↔ Will Anderson, Sauce ↔ Ahmad Gardner) — same person. Name agreement
  among matched is 95.7%, and every disagreement inspected is benign. We still
  apply a `normalize_name()` guard (decision 0013) as a tripwire, and corroborate
  with nflverse's own `cfb_player_id` (present on ~90% of picks) — but the
  authoritative key is the draft slot, which is unique per class by construction
  (decision 0011: one pick per player). This yields a crosswalk
  `collegeAthleteId ↔ gsis_id / pfr_player_id`.
  - *Rejected:* joining on `nflAthleteId = espn_id` (0% match — wrong namespace);
    name-only matching (~79%, collision-prone).

- **"How long they last" — seasons on an NFL roster (primary).** Career length =
  count of distinct NFL seasons a player appears on a roster
  (`load_rosters()`, distinct `season` per `gsis_id`). Roster presence is the
  cleanest "still in the league" signal and, unlike a stats-based definition,
  counts linemen, special-teamers, and backups who accrue no box-score stats.
  Report alongside it, from `load_draft_picks()`' PFR career fields, **games
  played** (`games`) and **last season played** (`to`); `seasons_started` and
  `car_av` are available as depth measures.
  - *Rejected as primary:* "seasons with recorded stats" (undercounts non-stat
    positions); games-only (misses roster-but-inactive years).
  - **Right-censoring is explicit.** Players from recent classes (≈2022–2026) are
    still active, so their careers are censored, not complete. Career length must
    be treated as censored (a survival outcome / "≥ k seasons"), never as a
    finished total — mixing censored and complete careers would bias any "how
    long" summary downward for recent picks.

- **Grain — player-season for stats; career summary is derived.** The raw NFL
  stats table is **player-season** (`gsis_id × season`, regular season),
  aggregated from weekly `load_player_stats()` (offense + defense). This is the
  flexible base; a **career-summary** view (one row per drafted player: seasons
  on roster, games, last season, career AV, career stat totals) is a
  **features-stage derivation** from the season table + draft-pick PFR fields,
  not a separate raw ingest.
  - *Rejected:* ingesting career summary directly as the primary table — it
    throws away the season trajectory (rookie-year vs. peak vs. decline) that the
    per-season grain preserves and that the fan's "what stats" question invites.

Raw NFL pulls this commits us to (all season-scoped to 2010–2026):
`load_draft_picks()` (link keys + PFR career fields), `load_rosters()` (roster
presence → career length), `load_player_stats()` (season stats). Like the team
display dimension (0008) and recruiting link (0013), NFL outcomes stay **off the
model input path** initially — they are *outcomes/labels*, and feeding them back
as features would be leakage. Wiring specific NFL outcomes into a supervised
target is separate future work.

## Hypotheses / expectations

- The draft-slot join holds at ≥99% for every class 2010–2026 and never inflates
  rows (one pick per slot per class), so no silent join loss.
- Roster-seasons is a fuller "longevity" measure than stat-seasons; the gap
  between them is concentrated in OL / ST / backup positions.
- Censoring materially affects 2022+ classes; any longevity summary that ignores
  it will understate recent picks' careers.

## Consequences

- New dependency `nflreadr` (adds its transitive deps); record in `DESCRIPTION`.
- New pipeline tables + targets following the established pattern
  (`*_file` → `raw_*` → cleaned), each with a `pointblank` contract, an
  `inst/dict/*.yml` dictionary (dict-parity test, decision 0010), an audit
  record (decision 0005), and `testthat` coverage. Candidate names:
  `nfl_draft_link`, `nfl_player_season`.
- `data-raw/refresh.R` gains the nflverse pulls; per the AGENTS.md gotcha, the
  new parquet **must be published to the `data-latest` release** before a fresh
  CI/site build can find it. nflverse pulls need network but **no API key**
  (unlike CFBD), so `data-refresh.yaml` needs no new secret.
- Commits us to treating NFL outcomes as labels, not features, until a leakage-safe
  target is designed.

## Outcome / what we learned

Implemented as three tables (`nfl_draft_picks`, `nfl_rosters`,
`nfl_player_stats`) plus `link_nfl_draft()`. The slot join is as clean as the
spike predicted; after the name guard, **~97% of 2010+ picks** carry validated
nflverse ids (a few points below the raw 99.7% because the guard nulls genuine
different-name links and a small share of picks find no slot). A first end-to-end
read gives a **median of 5 NFL seasons on a roster** and **45 career games** for
matched picks, with ~8% never appearing on a roster — plausible, and a reminder
that recent classes are censored.

Contracts earned their keep on first contact with the real data: `nfl_rosters`
carried impossible weights (0, 18, 449, 1794 lbs) — the `0` is the same
placeholder as CFBD `/roster` (decision 0009) — now coerced to `NA` outside a
100–500 lb range; and `nfl_player_stats` had 16 unattributed weekly rows with a
null `player_id`, dropped in cleaning. `car_av` arrived all-`NA` for the window
and was dropped in favor of `w_av`/`dr_av`. `nflreadr` needs no API key, so the
refresh job gains no secret; `load_player_stats()` errors on a not-yet-played
season, so that ingest clamps to `<= most_recent_season()` (2026 stats absent by
design, as with CFBD season stats).
