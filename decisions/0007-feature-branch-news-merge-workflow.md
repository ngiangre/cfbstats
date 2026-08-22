# 0007 — Feature-branch → NEWS → squash-merge workflow

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

The Git conventions (AGENTS.md, VISION.md §11) already call for short-lived
`feat/`/`data/`/`model/` branches, a linear history via squash-merge, and a
decision log. What was missing was a single, repeatable "how work lands on
`main`" recipe — including how changes get surfaced to a reader who isn't
reading commit messages, and how the decision log stays discoverable from the
public site. This entry formalizes that recipe so it doesn't have to be
re-derived each time.

## Decision

Most substantive work follows this workflow:

1. **Branch.** Cut a short-lived `feat/`/`data/`/`model/` branch off `main`.
2. **Work + contracts.** Make the change; add/update `testthat` and `pointblank`
   contracts alongside any data-touching code.
3. **Record decisions.** For substantive choices, add a `decisions/NNNN-*.md`
   entry (copy `TEMPLATE.md`, next number).
4. **Update `NEWS.md`.** Summarize user-facing changes under the development
   version heading and **link the relevant decision records** (via full GitHub
   URLs so the links resolve both on GitHub and on the deployed site).
5. **Green CI.** Let `check.yaml` (R CMD check + testthat + contracts) pass.
6. **Squash-merge** into `main` with a Conventional Commit summary, keeping a
   linear history; delete the branch.

`NEWS.md` lives at the package root and is surfaced on the website
automatically through altdoc's `$ALTDOC_NEWS` slot (already wired in
`altdoc/quarto_website.yml`), so the changelog + its decision links are the
site's entry point into project history.

Alternatives not chosen: merge commits (noisier history); a hand-maintained
CHANGELOG separate from `NEWS.md` (R packages already standardize on `NEWS.md`,
and altdoc surfaces it for free); linking decisions by relative path (breaks on
the deployed site, which does not ship `decisions/`).

## Hypotheses / expectations

- A fixed recipe lowers the friction of doing the right thing (records +
  changelog) so it actually happens on each merge rather than being skipped.
- Linking decisions from `NEWS.md` makes the "why" discoverable to site readers,
  not just people reading the repo.
- Squash-merge keeps `main` linear and each landed unit of work legible.

## Consequences

- Every merge is expected to touch `NEWS.md`; an empty changelog entry is a smell.
- `decisions/` is `.Rbuildignore`d and not shipped to the site, so cross-links
  must use GitHub URLs, not relative paths.
- Site CI renders reuse a committed Quarto freeze cache (`_quarto/_freeze/`,
  re-included in `.gitignore`) via `altdoc::render_docs(freeze = TRUE)` for
  faster, deterministic builds; the cache is refreshed by a local render when
  vignette code or inputs change.

## Outcome / what we learned

_Filled in later._
