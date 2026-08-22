# 0004 — Adopt `targets` orchestration and a pipeline stage taxonomy

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

VISION.md (§7) commits to a `targets` pipeline covering download → clean →
feature engineering → modeling → reporting, but ingestion so far lives in an
ad-hoc script ([data-raw/DATASET.R](../data-raw/DATASET.R)) with no dependency
graph, caching, or record of what is stale. We also want a single authoritative
**process map/DAG** and a **lineage** substrate (decision 0005) rather than a
hand-maintained flowchart that drifts from reality.

## Decision

Adopt [`targets`](https://books.ropensci.org/targets/) **now** as the pipeline
backbone and the single source of truth for the processing graph.

- Refactor the ingestion in `data-raw/DATASET.R` into pure `R/ingest_*.R`
  functions (one per CFBD endpoint); `data-raw/` is retained as thin runners /
  exploration scratch.
- `_targets.R` organizes targets into an explicit stage taxonomy:
  **ingest → clean → link → features → model → report**. `model` and `report`
  begin as wired placeholders.
- The process map/DAG (decision 0006) is rendered from the graph
  (`tar_mermaid()`, `tar_visnetwork()`), and "what remains / what's stale" comes
  from `tar_outdated()` / `tar_progress()`.
- Contracts (`pointblank`) run as targets so broken assumptions fail the graph.

Alternatives rejected: (a) staying with scripts — no lineage, no staleness
tracking; (b) a Make/`{drake}` approach — `targets` is the maintained successor
and integrates with the R-package workflow we already use.

## Hypotheses / expectations

- The DAG plus caching removes the "which step is out of date?" guesswork and
  makes the process map trustworthy because it is generated, not drawn.
- Pure ingest functions are far easier to test and contract-check than the
  monolithic script.

## Consequences

- New top-level `_targets.R` and a `_targets/` store (gitignored).
- CI likely builds the site from published release assets rather than running
  the full pipeline (network-bound); the scheduled refresh job runs the pipeline
  (see decision 0006 / VISION §11). To be confirmed as CI lands.
- Roster ingestion (decision 0003) is added as new ingest targets.

## Outcome / what we learned

_Filled in later._
