# 0017 — the targets pipeline ingests, processes, and writes all data assets

- **Status:** Accepted
- **Date:** 2026-08-29

## Context

Data production was split across three places: `data-raw/refresh.R` ingested the
CFBD/nflverse tables and wrote raw parquet; `data-raw/conference_tiers.R`
separately built the season × conference tier lookup; and the `targets` pipeline
only *read* the committed parquet (`*_file` → `raw_*` → `clean_*`) and, since
decision 0016, bundled the cleaned tables into DuckDB. The `data-refresh`
workflow therefore had to orchestrate the sequence by hand — download existing
assets, run `refresh.R`, then `tar_make(duckdb_file)` — and `conference_tiers`
was never refreshed by that job at all (it depended on a manually maintained
asset). The pieces could drift: a fresh `player_stats` with a new conference
would not get a tier until someone re-ran the standalone script.

## Decision

Make the `targets` pipeline the single owner of ingest → process → asset
production. One `tar_make()` in refresh mode ingests every source (including
`conference_tiers`, now derived in-pipeline from the ingested `player_stats`),
processes it, and writes every data asset — the raw parquet **and** the DuckDB
bundle — in one dependency-ordered pass.

Ingestion is env-gated so the same DAG still runs offline. Each raw table is a
`format = "file"` target whose command is `parquet_asset(path, build)`:

- **Refresh mode** (`CFBSTATS_REFRESH=true`): call `build()` (the `ingest_*()`
  function, or `build_conference_tiers()` for tiers) and **write** the parquet.
- **Track mode** (default): assume the parquet already exists (committed or
  downloaded from the `data-latest` release) and just track it — **no API call,
  no key**.

The ingest file targets carry `cue = tar_cue(mode = "always")` so a repeat local
refresh always re-ingests; in track mode the command merely returns the path
(cheap) and downstream rebuilds only when a file hash actually changes.
`build_conference_tiers()` (moved from `data-raw/conference_tiers.R` into
`R/conference_tiers.R`) makes the tier lookup a pure function of `player_stats`,
so it refreshes automatically.

`data-raw/refresh.R` becomes a thin wrapper (`Sys.setenv(CFBSTATS_REFRESH=…)` +
`tar_make()`); `data-raw/conference_tiers.R` is removed. The `data-refresh`
workflow is now just `tar_make()` with `CFBSTATS_REFRESH=true` and the CFBD key,
then upload `data/*.{parquet,duckdb}`.

Alternatives not picked: making ingestion unconditional in the DAG (would break
the keyless site build, which runs `tar_make()` on downloaded assets); keeping
`refresh.R` as the ingest owner outside the graph (the split the user asked us to
remove); rebuilding `conference_tiers` outside the pipeline (the drift we are
fixing).

## Hypotheses / expectations

- A single refresh command produces a mutually consistent asset set (parquet +
  DuckDB + tiers all from the same ingest), removing drift and manual sequencing.
- The env gate preserves keyless, offline `tar_make()` for the site build and
  for analysis against downloaded assets.
- `conference_tiers` staying a pure function of `player_stats` means new
  conferences in a refresh get a tier automatically (defaulting to tier 1),
  caught by `contract_conference_tiers()` coverage rather than silently dropped.

## Consequences

- The full pipeline splits into two runtime modes; the mode lives in an env var,
  not the tracked command, so `tar_outdated()` cannot see it — hence the
  `always` cue on the ingest targets and the rule that **refresh is explicit**
  (`CFBSTATS_REFRESH=true`).
- Track mode errors clearly if an asset is missing (`parquet_asset()` guards it),
  pointing at either refreshing or downloading the release.
- Adding a new source now means: an `ingest_*()`, a `parquet_asset()` file
  target + its `raw_*` reader, clean/contract/dict as before, and adding it to
  the `duckdb_file` table list and `inst/data-model.md` — all in `_targets.R`.
- `data-raw/conference_tiers.R` is gone; decision 0003's tier logic now lives in
  `build_conference_tiers()`.

## Outcome / what we learned

_Filled in later._
