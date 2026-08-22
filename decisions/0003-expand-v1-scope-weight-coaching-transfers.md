# 0003 — Expand v1 scope: weight change, coaching changes, transfers

- **Status:** Accepted
- **Date:** 2026-08-21

## Context

Collaborator feedback: v1 should capture three things a modern player's path
turns on, none of which the current snapshot grain represents:

1. **Weight gain/loss between seasons** — physical development year over year.
2. **Coaching changes** — head coaches move schools frequently; a player's HC
   can change under them, or a player can follow a coach.
3. **Transfers** — the transfer portal era; players change schools freely.

The motivating question is directional: does moving around **help or hurt**
draft outcome? Illustrative trajectories:

- A 5★ QB: Los Alamitos HS → USC (2023, redshirt) → Boise State (2024) →
  UTEP (2025) → Syracuse (2026) — G5 → P4 climb chasing a starting job.
- Quinn Ewers — would staying vs. transferring again have changed his round?
- Cam Ward — 0★, Incarnate Word (FCS) → Washington State → Miami → No. 1
  overall. An FCS → FBS jump the P4/G5 binary alone would miss.

All three are **between-season change** features, not properties of a single
player-season. That is the core reframing this entry commits to.

### Enabling finding — player linkage is effectively solved (see also 0001)

The long-standing linkage problem (`picks.collegeAthleteId` int vs.
`player_stats.playerId` string) was investigated empirically:

- `player_stats.playerId`, the `/roster` endpoint's `id`, and
  `picks.collegeAthleteId` are **the same athlete-id namespace**. 100% of the
  13,566 distinct `player_stats` ids for 2023 appear in the 2023 roster.
- Coercing `collegeAthleteId` (int) → string joins **directly** to
  `player_stats.playerId`; no fuzzy name matching required.
- From draft year **2013 onward, ~98–100% of picks carry a
  `collegeAthleteId`**. Missing ids are pre-2013 drafts, outside our 2010–2025
  stats window. Name-based matching (the prior approach) linked ~28% of picks;
  id coercion is both more reliable and clearer about what it misses.

So the athlete id is our stable player key. `/roster` is not strictly required
for the pick→stats join, but it confirms the shared namespace and is needed
independently for per-season weight and as a full player-season backbone
(it includes players with no qualifying stat line, e.g. many linemen).

## Decision

**1. Adopt athlete id as the canonical player key.** Coerce
`picks.collegeAthleteId` to string and join to `player_stats.playerId` /
`roster.id`. Retire name-based matching except as a fallback/QA cross-check.

**2. Add a longitudinal (career-sequence) layer.** Link each player's seasons
in chronological order and derive lagged/delta features on the player-season
row, rather than re-modeling to a pure trajectory grain:

- `weight_delta` = weight(t) − weight(t−1), from `/roster`.
- `transferred` = team(t) ≠ team(t−1) for the same athlete id (derivable today
  from `player_stats`; ~16% of players already appear at ≥2 teams). Optionally
  enrich with `/player/portal` (stars, rating, transfer date) for recent years.
- `hc_changed` = head coach of the player's team differs from t−1; and
  `followed_coach` = player's new-team HC(t) == player's prior-team HC(t−1),
  both derived from the existing `coaches.parquet` (school × year per coach id).

**3. Ingest `/roster` by year (2010–2025)** for per-season height, weight,
position, jersey, and hometown, keyed by athlete `id`.

**4. Conference-tier scheme for transfer *direction*: a 3-tier, season-aware
mapping** (revisable):

| Level | Tier | Members (season-dependent) |
|-------|------|----------------------------|
| 3 (highest) | Power | SEC, Big Ten, Big 12, ACC; Pac-12/Pac-10 through 2023; Big East football through 2012; Notre Dame |
| 2 | Group of 5 / other FBS | American Athletic, Mountain West, Mid-American, Sun Belt, Conference USA; FBS Independents (non-ND) |
| 1 (lowest) | FCS and below | all FCS conferences (Big Sky, CAA/Coastal, MVFC, Ivy, Patriot, …) and DII/DIII |

Transfer direction = sign(level(dest, season) − level(origin, season)): **up**
(+), **lateral** (0), **down** (−). The mapping is a season-keyed lookup because
conference names and memberships shift over 2010–2025 (Pac-12 collapse, Big
East → AAC, realignment).

Alternatives considered and rejected for v1:
- **P4/G5 binary** — loses FCS↔FBS jumps that the Cam Ward archetype is about.
- **Conference-by-conference finer tiers** — unstable across realignment,
  sparse cells, and no natural "direction." A continuous program-strength
  measure (season SP+/SRS, which we already ingest via `/coaches`) is noted as
  a *later* complement/replacement, but discrete tiers win on interpretability
  for v1.

## Hypotheses / expectations

- Id-based linkage lifts reliable pick→stats coverage well above the ~28%
  name-based baseline within 2013+ and removes silent mismatch/duplication.
- Transfer *direction* carries more draft signal than the fact of transferring;
  upward (G5→P4, FCS→FBS) moves associate with better draft odds after
  adjusting for production, though selection (better players get poached) will
  confound the naive comparison.
- Following a coach and positive weight trajectory (position-appropriate) add
  marginal signal.

## Consequences

- New ingestion in `data-raw/`: `/roster` by year (and optionally
  `/player/portal`). Add matching data contracts (expected years, id coverage,
  weight ranges, no silent join loss).
- Grain now carries lag features → the pipeline must sort/link a player's
  seasons and guard the out-of-time rule (a lag may only use prior-season data;
  no leakage from the predicted draft class).
- Need a maintained **season × conference → tier** lookup table in the package.
- VISION.md updated: v1 scope, data sources, ERD (add ROSTER_SEASON + derived
  transfer/coach-change/weight-delta features), and the linkage "known issue"
  is downgraded from unsolved to resolved-via-athlete-id.

## Outcome / what we learned

**Weight change is not derivable from `/roster` (2026-08-22).** Two findings
came out of actually ingesting `/roster`:

1. **The endpoint's `year` field is the player's eligibility class (1–5), not the
   season.** Trusting it gave only ~29% key coverage that decayed to ~0% in
   recent years. Stamping `season` from the *queried* year instead lifted
   `(playerId, season)` match against the stats backbone to **99.5%** and weight
   coverage to ~81%. `ingest_roster()` now stamps the season and renames the raw
   field to `class_year`.
2. **Roster weight is static per player** — repeated across every season. Of
   ~43,700 multi-season players with a weight, **0** show any change. So a
   between-season `weight_delta` is structurally always 0 and is **dropped**.
   We keep the static roster `weight` as a physical attribute
   (`add_roster_weight()`). A genuine physical-development feature would need a
   different source (e.g. recruiting weight → draft weight span). The v1 "weight
   gain/loss between seasons" goal is therefore **not met from `/roster`**; the
   transfer-direction and coaching-change features are unaffected.

Still open: did directional transfers beat the transfer flag? Any id-linkage
surprises (id reuse, mid-season team changes)?
