# 0013 — Recruiting ratings: id-namespace collision and the name guard

- **Status:** Accepted
- **Date:** 2026-08-24

## Context

We had no high-school recruiting ratings in the dataset. CFBD's
`/recruiting/players` endpoint returns industry `stars` (2–5), a composite
`rating` (~0.74–1.0), and a national `ranking`, plus an `athleteId` that *looks*
like the shared athlete-id namespace (decision 0003) used to join
`player_stats.playerId` / `roster.id` / `picks.collegeAthleteId`.

Prototyping the join surfaced a serious problem. Joining recruiting to picks on
`athleteId` alone attached a **3-star** rating to Cam Ward — but that id
(`4688380`) maps in the recruiting feed to a *different person*, **Xavier Ward**
(a WSU-committed QB from California). The real Cam Ward, unranked out of a Texas
wishbone offense, is **absent** from the recruiting feed entirely. So the id
join did not "find his rating"; it silently attached someone else's.

This is not a one-off. Checking name agreement on the ~12,700 id-linked records,
~12% disagree on name; most are benign formatting/suffix differences, but a
material share are genuine different-person collisions (e.g. Tony Jones Jr. ↔
Jamir Jones), and same-surname collisions like Cam ↔ Xavier Ward slip past a
surname check. The recruiting `athleteId` is therefore **a separate id space
that only sometimes coincides** with the roster/stats/picks namespace — it
violates the decision 0003 assumption of one clean athlete-id namespace, unlike
`collegeAthleteId` (which is the same namespace, decision 0011).

## Decision

Ingest the recruiting feed and publish it (`ingest_recruiting()`,
`data/recruiting.parquet`, on the `data-latest` release), but treat its
`athleteId` as **untrusted** and never join on it alone.

- `clean_recruiting()` standardizes the feed to a **per-athlete** rating table
  keyed by string `playerId`: it drops recruits with no `athleteId` (~40% —
  never enrolled, JUCO/international, unlinked) and dedupes to one row per
  athlete (highest `rating`, then `stars`, then most recent class).
- `link_recruiting()` attaches ratings to the player-season backbone with a
  **normalized-name guard**: a rating is trusted only when the recruiting name
  agrees with the backbone `player` name after `normalize_name()` (lowercase,
  strip punctuation, drop Jr./Sr./II–V). Name-conflicting (wrong-person) links
  have their ratings set to `NA`, flagged by `recruit_matched`. The recruiting
  table is one row per `playerId`, so the join is many-to-one and never inflates
  the backbone.
- `contract_recruiting()` validates the cleaned table (1:1 non-null `playerId`,
  `stars` 2–5, `rating` 0.7–1.0, `hs_class` in window); the collision itself is
  a join-time concern handled by the guard, not the contract.
- The `committed_to` field is retained but flagged unreliable: for Cam Ward's
  colliding record it reads "Washington State", not his actual first school
  (Incarnate Word), so it can reflect a later/updated commitment.

Alternatives not chosen: (a) joining on `athleteId` alone — rejected, it silently
attaches wrong-person ratings; (b) fuzzy name+hometown+class matching without ids
— deferred, heavier and not needed once the id link is name-guarded; (c) chasing
another rating source (ESPN/On3/Wikidata) — rejected for now, CFBD already draws
on the 247 composite and an unranked player like Cam Ward has no rating to find
anywhere, so the absence is itself informative and should be modeled as an
"unrated recruit" category rather than imputed.

`link_recruiting()` is kept **off the model path** for now (like the team
display dimension, decision 0008); wiring HS rating into the model is future
work.

## Hypotheses / expectations

- The name guard removes wrong-person ratings without materially hurting honest
  coverage: guarded coverage of drafted players is ~60–72% for recent classes
  (2021–2025), a few points below the inflated id-only number; ~5% of id-linked
  drafted players are rejected as collisions.
- Treating "no validated rating" as a real category (unrated / off-radar) will
  be predictive in itself — reaching the NFL despite being unranked is signal.

## Consequences

- Adds a first-class recruiting table to the pipeline: `recruiting_file` →
  `raw_recruiting` → `recruiting`, with `ok_recruiting`, an audit record, a
  `pointblank` contract, a data dictionary (`inst/dict/recruiting.yml`, guarded
  by the dict-parity test), and `tests/testthat/test-recruiting.R`.
- `data-raw/refresh.R` now pulls recruiting; the parquet must be published to
  the `data-latest` release for a fresh CI/site build to find it (AGENTS.md
  gotcha) — done for this change.
- Any future use of recruiting ratings must go through `link_recruiting()` (or
  an equivalent name guard); joining `recruiting.playerId` directly is unsafe.

## Outcome / what we learned

_Filled in later._
