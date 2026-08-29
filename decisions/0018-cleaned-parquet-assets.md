# 0018 — published parquet are the cleaned tables (parquet == DuckDB)

- **Status:** Accepted
- **Date:** 2026-08-29

## Context

After decisions 0016–0017 the pipeline published two asset kinds with *different*
schemas: the `data/*.parquet` files were the **raw** ingest (what the `*_file`
targets read as `raw_*`, then `clean_*`), while `data/cfbstats.duckdb` bundled
the **cleaned** tables. A consumer comparing `picks.parquet` (raw, no `playerId`
/`drafted`) to the DuckDB `picks` table (cleaned) saw mismatched columns, and the
data dictionaries (`inst/dict/*.yml`) — which document the *cleaned* schemas —
matched only the DuckDB. The published parquet did not match the dictionaries.

## Decision

Make the published parquet the **cleaned** tables, so parquet, DuckDB, and the
dictionaries all carry one identical schema per table.

Restructure ingest/clean in `_targets.R`:

- `raw_*` targets ingest **in memory** in refresh mode only
  (`if (refresh_enabled()) ingest_*()`), and are `NULL` in track mode. They are
  no longer persisted or published.
- `<table>_file` (`format = "file"`) is the published **cleaned** parquet:
  `parquet_asset(path, function() clean_*(raw_*))` — refresh mode cleans the
  freshly ingested raw and writes the parquet; track mode tracks the existing
  committed/downloaded file (no key, **no re-clean**).
- `<table>` reads the cleaned parquet, making it the single source of truth for
  everything downstream (contracts, links, features, and the DuckDB bundle).
- `conference_tiers` derives from the **cleaned** `player_stats`.

The DuckDB bundle is unchanged (it already bundled the cleaned tables); it now
simply equals the cleaned parquet.

Alternatives not picked: publishing both raw and cleaned parquet (release assets
are a flat namespace, so `picks.parquet` would collide; and it re-introduces the
schema-mismatch confusion); collapsing `raw_*` into the clean thunk entirely
(loses the raw input the audit log uses to compute rows-dropped in refresh).

## Hypotheses / expectations

- One schema per table across parquet / DuckDB / dictionaries removes a foot-gun
  and keeps `inst/data-model.md` accurate for every asset.
- Track-mode builds get *faster* and simpler: they read cleaned parquet directly
  instead of reading raw and re-running every `clean_*`.
- Keeping `raw_*` as in-memory refresh-only targets preserves the audit
  rows-dropped delta when it is meaningful (refresh), and `audit_step()` already
  reports `NA` for those deltas when the raw input is `NULL` (track mode).

## Consequences

- The raw ingest is no longer a persisted artifact; to inspect raw vs cleaned,
  run a refresh (the raw lives in the `raw_*` targets' store during that run).
- `clean_*` functions run only in refresh mode; a change to one is not reflected
  in track-mode builds until the next refresh republishes the parquet.
- The first refresh after this change rewrites every `data/*.parquet` from raw to
  cleaned on the `data-latest` release; older raw-schema assets are replaced.
- Supersedes the "parquet are raw / DuckDB is cleaned" split noted in decisions
  0016–0017.

## Outcome / what we learned

_Filled in later._
