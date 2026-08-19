# 0002 — Ignore analysis/infra files from the R package build

- **Status:** Accepted
- **Date:** 2026-08-18

## Context

The repo is developed as an R package (decision 0001) so we can lean on the
`devtools` workflow — `load_all`, `document`, `test`, and `check` — to enforce
our own conventions and standards on the reusable code in `R/`. But this is an
*analysis project*, not a package headed for CRAN: it also contains a Quarto
site, a decision log, agent/skill config, raw-data scripts, and (potentially)
data artifacts. Left in the build, those would produce `R CMD check` NOTEs/
WARNINGs and slow or break the check without telling us anything useful about
code quality.

## Decision

Use `.Rbuildignore` to exclude non-package material from the build so
`devtools::check()` serves as a **conventions/standards gate**, not a
submission-readiness gate. We are explicitly *not* aiming for a
CRAN-submittable, NOTE-free package.

Expected to ignore (refine as the structure lands): `VISION.md`,
`decisions/`, `.claude/`, `data/`, `data-raw/`, the Quarto site
directory/outputs (e.g. `_site/`, `*.qmd` site sources as appropriate), and
similar non-code assets.

Alternatives considered: (a) not using a package structure at all — rejected,
we want the `devtools`/`roxygen2` discipline; (b) making a fully
CRAN-clean package — rejected as unnecessary overhead for a personal analysis
project.

## Hypotheses / expectations

- `check()` will stay fast and its output will be *signal* about the `R/` code
  (documentation, examples, `NAMESPACE`, tests) rather than noise about
  analysis files.
- We can tolerate residual NOTEs that don't reflect code-quality issues.

## Consequences

- Maintain `.Rbuildignore` as the repo grows; new top-level analysis artifacts
  should be added to it.
- `check()` failures should be read as convention/standard violations worth
  fixing, not as submission blockers.

## Outcome / what we learned

_Filled in later._
