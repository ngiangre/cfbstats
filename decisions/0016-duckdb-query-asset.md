# 0016 — DuckDB query asset & data-model documentation

- **Status:** Accepted
- **Date:** 2026-08-29

## Context

The project ships ten cleaned tables as parquet on the `data-latest` release.
Parquet is great for the R pipeline but awkward for ad-hoc, cross-table SQL: a
user wanting to answer "drafted rate by conference tier" or "NFL seasons per
drafted player" has to open several files and reconstruct the joins by hand. The
join structure itself is non-obvious — five distinct namespaces, two of which
(`recruiting.playerId`, `picks.nflAthleteId`) *look* joinable but are not
(decisions 0013, 0014). We wanted (a) a single queryable artifact and (b) a
durable, human-readable map of how the tables relate and how to reason over them
for the modeling question, anchored to the existing per-table dictionaries.

## Decision

Add a `build_duckdb()` function (`R/duckdb.R`) that bundles the **cleaned**
tables into one DuckDB file, and wire it into the pipeline as the
**`duckdb_file`** target (`_targets.R`, `format = "file"`) downstream of the
clean stage. Building from the cleaned target objects — not the raw ingest
parquet — means the DuckDB schema matches `inst/dict/*.yml` exactly. Publish
`data/cfbstats.duckdb` alongside the parquet on `data-latest`.

Because the build is a pipeline target, publishing runs through `targets`: the
`data-refresh` workflow now downloads the current release assets first (so the
package-maintained `conference_tiers.parquet`, which the refresh does not
regenerate, is present), runs `data-raw/refresh.R`, then
`tar_make(duckdb_file)`, then uploads the parquet **and** the `.duckdb` file.
The `site` workflow's full `tar_make()` also builds the target (duckdb added to
both workflows' R dependencies).

Document the model in `inst/data-model.md`: a Mermaid ERD, the five join
namespaces (and the two false ones), leakage/out-of-time guidance tied to the
drafted outcome, and example SQL — cross-linking each table to its
`dict/<table>.yml`.

Alternatives not picked: building the DuckDB from the parquet on disk (would
capture raw, not cleaned, schemas and drift from the dictionaries); a SQLite
bundle (weaker analytic SQL, no native parquet); calling `build_duckdb()` inside
`refresh.R` (would sidestep the DAG the user asked us to use, and duplicate the
clean logic).

## Hypotheses / expectations

- A single DuckDB file lowers the barrier to exploratory cross-table SQL and to
  non-R consumers, without changing the R pipeline.
- Building from cleaned targets keeps the asset's schema identical to the
  dictionaries, so `inst/data-model.md` stays accurate for both.
- Documenting the namespaces in one place reduces wrong-namespace joins
  (especially the `recruiting` / `nflAthleteId` traps).

## Consequences

- `DBI` and `duckdb` added to `Suggests`; both CI workflows install `duckdb`.
- `data/cfbstats.duckdb` is gitignored like the rest of `data/`; it lives only
  on the release. Its bytes are not reproducible, so `targets` may always see
  `duckdb_file` as outdated — it simply rebuilds, which is cheap.
- The `data-refresh` job now depends on the release already existing for its
  pre-download step (guarded; a first run just logs and proceeds).
- New tables must be added to the `duckdb_file` target's table list and to
  `inst/data-model.md`, alongside the existing dict/contract obligations.

## Outcome / what we learned

_Filled in later._
