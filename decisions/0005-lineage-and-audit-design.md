# 0005 — Lineage and audit design

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

A core project value (VISION §8) is faithfulness to the raw data and
transparency about every transformation: we want to trace any statistic or
prediction back to the rows and code that produced it, and never discover after
modeling that players, coaches, years, or columns were silently lost or
misrepresented. That requires a concrete, uniform record of what each pipeline
step does to the data — not just prose.

## Decision

Build a lineage/audit layer on top of the `targets` graph (decision 0004) with
three components:

**1. A per-step audit record.** A helper (`R/audit.R`, `audit_step()` /
`tar_audit()`) captures, for each transform, a uniform row:

- step name and pipeline stage;
- input and output **row and column counts**, and **rows dropped**;
- **join-key coverage** (distinct keys in/out, unmatched keys);
- per-column **NA counts** and a **schema hash** (column names + types) for
  schema-stability tracking across data refreshes;
- the governing **data contract's pass/fail** and a brief summary;
- **timestamp** and **git SHA**.

These accumulate into a single audit tibble (a dedicated target) rendered on the
site's Data > Provenance/Audit page.

**2. Data dictionaries.** One YAML per raw and key processed dataset in
`inst/dict/`: endpoint/source, grain, key, and per-column type + description +
provenance. Rendered as browsable tables on the site.

**3. Contracts wired into the graph.** `pointblank` agents (extending the
existing `contract_conference_tiers()`) run as targets; their `all_passed`
status and summary feed the audit record so contract health is visible per step.

Alternatives rejected: bespoke per-script logging (not uniform, drifts);
relying on `targets` metadata alone (tracks staleness, not data-quality deltas).

## Hypotheses / expectations

- A uniform audit record makes silent join loss and schema drift visible the
  moment they happen, and gives the site an honest provenance story for free.
- Schema hashing catches upstream CFBD changes on the scheduled refresh before
  they corrupt features.

## Consequences

- Processing functions must expose enough for the audit helper to compare
  input/output (either return both, or be comparable via named upstream
  targets). Kept flexible for now; convention firmed up as features land.
- `inst/dict/` dictionaries must be maintained alongside schema changes.

## Outcome / what we learned

_Filled in later._
