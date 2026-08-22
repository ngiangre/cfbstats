# 0006 — Quarto site architecture, reference docs, and viz stack

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

VISION (§7, §10) calls for a Quarto website on GitHub Pages that unifies code
documentation and analysis narrative, includes a blog, data/analysis pages, a
process map, and interactive visualizations for both non-technical fans and
R/stats coders. We need to fix an initial site structure, how roxygen reference
docs get onto the site, and a default interactive-viz stack — while keeping all
three easy to revise.

## Decision

**Site structure.** A Quarto website with navbar sections: Home, About (from
README/VISION), **Data** (dictionaries + provenance/audit, decision 0005),
**Pipeline** (process map/DAG rendered from `targets`, decision 0004),
**Analysis** (blog + analysis pages), **Explore** (interactive exemplars), and
**Reference** (roxygen). `execute: freeze: auto` for reproducible renders; qmd
pages read pipeline outputs via `targets::tar_read()`. Theme via `bslib`/brand.

**Reference docs via `altdoc`.** Use [`altdoc`](https://altdoc.etiennebacher.com)
to surface roxygen documentation as the site's Reference section, keeping code
docs and narrative in one Quarto site (rather than a separate `pkgdown` site).
Proposed default, revisable if altdoc's conventions prove constraining.

**Interactive viz: hybrid.** R **htmlwidgets** (`plotly`, `ggiraph`,
`reactable`, `leaflet`) are the default because they reuse ggplot2/R and keep
the data → widget lineage in one language; `plotly` covers 3D. **Observable JS**
is reserved for a few bespoke explorables where its interactivity clearly wins.
A `R/viz.R` module provides themed helpers (matched to the site theme via
`thematic`).

Alternatives rejected: `pkgdown` (separate site, splits docs from narrative);
OJS-first (second language + data-handoff boundary for every chart); static-only
plots (misses the interactivity the audience deliverables call for).

## Hypotheses / expectations

- One Quarto site for docs + narrative lowers maintenance and keeps results next
  to the code and data that produced them.
- R-default viz keeps most charts traceable to a single pipeline target;
  reserving OJS avoids over-investing in a second toolchain prematurely.

## Consequences

- New site sources + `_quarto.yml`; site output (`docs/`/`_site/`) gitignored and
  built by GitHub Actions.
- Small open choice: site source dir (`site/` vs altdoc's `altdoc/`+`docs/`
  convention) — settled during implementation.
- Adds `plotly`/`ggiraph`/`reactable`/`thematic`/`altdoc` to Suggests.

## Outcome / what we learned

_Filled in later._
